import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import { createDashboardService } from '../../src/modules/admin/dashboard.service.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { now } from '../analytics/helpers.js';
import { dashboardStored } from './helpers.js';

async function fixture(limit = 1000) {
  const environment = { ...testEnvironment, ANALYTICS_RATE_LIMIT_MAX: limit };
  const auth = memoryRepository();
  const service = createAuthService(environment, auth.repository);
  const credentials = {
    email: 'admin-dashboard@example.invalid',
    password: 'synthetic test password',
  };
  await service.createAdmin(credentials);
  const grant = await service.login(credentials);
  const admin = grant.accessToken;
  const farmerCredentials = { ...credentials, email: 'farmer-dashboard@example.invalid' };
  await service.register(farmerCredentials);
  const farmer = (await service.login(farmerCredentials)).accessToken;
  const state = { calls: 0, fail: false };
  const dashboard = createDashboardService(
    {
      async summary() {
        state.calls++;
        if (state.fail) throw new Error('private-database-credentials');
        return dashboardStored();
      },
    },
    environment,
    () => now,
  );
  const app = createApp(
    environment,
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    undefined,
    undefined,
    undefined,
    undefined,
    undefined,
    undefined,
    dashboard,
  );
  return { app, admin, farmer, state, service, refreshToken: grant.refreshToken };
}
const path = '/api/v1/admin/dashboard';
function get(url: string, token?: string) {
  return fetch(url, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
}
test('every dashboard endpoint denies FARMER, missing, invalid and revoked ADMIN sessions before querying', async () => {
  const f = await fixture();
  await withServer(f.app, async (base) => {
    for (const suffix of ['', '?from=2026-10-01&to=2026-10-02', '?userId=forged']) {
      assert.equal((await get(base + path + suffix, f.farmer)).status, 403);
      assert.equal((await get(base + path + suffix)).status, 401);
      assert.equal((await get(base + path + suffix, 'invalid')).status, 401);
    }
    assert.equal(f.state.calls, 0);
    await f.service.logout(f.refreshToken);
    assert.equal((await get(base + path, f.admin)).status, 401);
    assert.equal(f.state.calls, 0);
  });
});
test('ADMIN receives bounded real-projection contract without identities, assets, tokens or accuracy', async () => {
  const f = await fixture();
  await withServer(f.app, async (base) => {
    const response = await get(base + path + '?from=2026-10-01&to=2026-10-02', f.admin);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    const body = (await response.json()) as {
      success: boolean;
      data: { scans: { totals: { totalScans: number } } };
      requestId: string;
    };
    assert.equal(body.success, true);
    assert.equal(body.data.scans.totals.totalScans, 8);
    assert.equal(body.requestId, response.headers.get('x-request-id'));
    for (const forbidden of [
      'email',
      'userId',
      'imageUrl',
      'artifactUri',
      'password',
      'accessToken',
      'accuracy',
    ])
      assert.ok(!JSON.stringify(body).includes(forbidden));
  });
});
test('ADMIN dashboard rejects invalid, forged-owner, partial, future and excessive filters', async () => {
  const f = await fixture();
  await withServer(f.app, async (base) => {
    for (const query of [
      'userId=forged',
      'limit=999',
      'from=2026-02-30&to=2026-03-01',
      'from=2026-01-01',
      'from=2024-01-01&to=2025-01-01',
      'from=2026-10-16&to=2026-10-16',
      'from=2026-10-02&to=2026-10-01',
      'from=2026-10-01&from=2026-10-02&to=2026-10-03',
    ]) {
      assert.equal((await get(base + path + '?' + query, f.admin)).status, 400, query);
    }
    assert.equal(f.state.calls, 0);
  });
});
test('dashboard failures remain safe and the aggregate endpoint is rate limited', async () => {
  const f = await fixture(1);
  f.state.fail = true;
  await withServer(f.app, async (base) => {
    const response = await get(base + path, f.admin);
    assert.equal(response.status, 500);
    const body = await response.text();
    assert.ok(!body.includes('private-database'));
    assert.ok(!body.includes('stack'));
    assert.equal((await get(base + path, f.admin)).status, 429);
    assert.equal(f.state.calls, 1);
  });
});
