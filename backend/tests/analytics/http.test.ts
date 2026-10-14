import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import { createAnalyticsService } from '../../src/modules/analytics/analytics.service.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { createFertilizerService } from '../../src/modules/fertilizer/fertilizer.service.js';
import { createGenerationService } from '../../src/modules/generation/generation.service.js';
import { createKnowledgeService } from '../../src/modules/knowledge/knowledge.service.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import { createYieldService } from '../../src/modules/yield/yield.service.js';
import { memoryRepository } from '../auth/helpers.js';
import { memoryFertilizer } from '../fertilizer/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { fakeGeneration } from '../generation/helpers.js';
import { memoryKnowledge } from '../knowledge/helpers.js';
import { fakeInference, fakeStorage, memoryScans } from '../scans/helpers.js';
import { memoryYield } from '../yield/helpers.js';
import { aggregate, memoryAnalytics, now } from './helpers.js';

async function fixture(limit = 1000) {
  const environment = { ...testEnvironment, ANALYTICS_RATE_LIMIT_MAX: limit };
  const auth = memoryRepository();
  const authService = createAuthService(environment, auth.repository);
  const tokens: Record<string, string> = {};
  const owners: Record<string, string> = {};
  for (const role of ['OWNER', 'OTHER', 'ADMIN']) {
    const credentials = {
      email: `${role.toLowerCase()}-analytics@example.invalid`,
      password: 'synthetic analytics credentials only',
    };
    if (role === 'ADMIN') await authService.createAdmin(credentials);
    else await authService.register(credentials);
    tokens[role] = (await authService.login(credentials)).accessToken;
    const account = auth.accounts.get(credentials.email);
    assert.ok(account);
    owners[role] = account.id;
  }
  const scans = createScanService(
    memoryScans().repository,
    fakeStorage().storage,
    silentLogger,
    fakeInference().client,
  );
  const knowledge = memoryKnowledge();
  const generated = fakeGeneration();
  const analytics = memoryAnalytics();
  const ownerId = owners.OWNER;
  assert.ok(ownerId);
  analytics.data.set(ownerId, aggregate());
  const app = createApp(
    environment,
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    scans,
    createKnowledgeService(knowledge.repository, knowledge.client),
    createGenerationService(scans, generated.client),
    createFertilizerService(memoryFertilizer().repository),
    createYieldService(memoryYield().repository),
    createAnalyticsService(analytics.repository, () => now),
  );
  return { app, tokens, owners, analytics };
}
async function get(url: string, token?: string) {
  return fetch(url, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
}
async function response<T>(result: Response, status = 200): Promise<T> {
  assert.equal(result.status, status);
  assert.equal(result.headers.get('cache-control'), 'no-store');
  const body = (await result.json()) as { success: boolean; data: T; requestId: string };
  assert.equal(body.success, status < 400);
  assert.equal(body.requestId, result.headers.get('x-request-id'));
  for (const field of [
    'userId',
    'passwordHash',
    'cloudinaryPublicId',
    'imageUrl',
    'stack',
    'private-connection',
  ])
    assert.ok(!JSON.stringify(body).includes(field));
  return body.data;
}
const range = 'from=2026-10-01&to=2026-10-02';
test('analytics summary/activity reject guests, invalid credentials and ADMIN sessions', async () => {
  const setup = await fixture();
  await withServer(setup.app, async (base) => {
    for (const path of ['/analytics/scans', '/analytics/scans/activity']) {
      await response(await get(`${base}/api/v1${path}`), 401);
      await response(await get(`${base}/api/v1${path}`, 'invalid'), 401);
      await response(await get(`${base}/api/v1${path}`, setup.tokens.ADMIN), 403);
    }
    assert.equal(setup.analytics.reads.length, 0);
  });
});
test('farmer gets only own totals; another farmer is empty and cannot use a foreign cursor', async () => {
  const setup = await fixture();
  await withServer(setup.app, async (base) => {
    const owner = await response<{ totals: { totalScans: number } }>(
      await get(`${base}/api/v1/analytics/scans?${range}`, setup.tokens.OWNER),
    );
    assert.equal(owner.totals.totalScans, 8);
    const other = await response<{ totals: { totalScans: number } }>(
      await get(`${base}/api/v1/analytics/scans?${range}`, setup.tokens.OTHER),
    );
    assert.equal(other.totals.totalScans, 0);
    await response(
      await get(
        `${base}/api/v1/analytics/scans/activity?${range}&cursor=${setup.analytics.ids[0]}`,
        setup.tokens.OTHER,
      ),
      404,
    );
    assert.equal(setup.analytics.reads[0]?.userId, setup.owners.OWNER);
    assert.equal(setup.analytics.reads[1]?.userId, setup.owners.OTHER);
    const page = await response<{ items: unknown[]; nextCursor: string }>(
      await get(`${base}/api/v1/analytics/scans/activity?${range}&limit=2`, setup.tokens.OWNER),
    );
    assert.equal(page.items.length, 2);
    assert.equal(page.nextCursor, setup.analytics.ids[1]);
  });
});
test('analytics rejects invalid/date/owner filters before repository work', async () => {
  const setup = await fixture();
  await withServer(setup.app, async (base) => {
    for (const query of [
      'from=2026-02-30&to=2026-03-01',
      'from=2026-10-01',
      'from=2026-10-03&to=2026-10-01',
      'from=2026-10-16&to=2026-10-16',
      'from=2024-01-01&to=2025-01-01',
      `userId=${randomUUID()}`,
      'from=2026-10-01&from=2026-10-02&to=2026-10-02',
    ])
      await response(await get(`${base}/api/v1/analytics/scans?${query}`, setup.tokens.OWNER), 400);
    for (const query of ['limit=0', 'limit=51', 'cursor=invalid', 'user_id=anything'])
      await response(
        await get(`${base}/api/v1/analytics/scans/activity?${query}`, setup.tokens.OWNER),
        400,
      );
    assert.equal(setup.analytics.reads.length, 0);
  });
});
test('analytics has a bounded shared limiter and centralizes database failures', async () => {
  const setup = await fixture(1);
  await withServer(setup.app, async (base) => {
    await response(await get(`${base}/api/v1/analytics/scans?${range}`, setup.tokens.OWNER));
    await response(
      await get(`${base}/api/v1/analytics/scans/activity?${range}`, setup.tokens.OWNER),
      429,
    );
  });
  const broken = await fixture();
  broken.analytics.repository.summary = async () => {
    throw new Error('private-connection');
  };
  await withServer(broken.app, async (base) => {
    await response(await get(`${base}/api/v1/analytics/scans?${range}`, broken.tokens.OWNER), 500);
  });
});
