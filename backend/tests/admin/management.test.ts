import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import { createManagementService } from '../../src/modules/admin/management.service.js';
import {
  draftDocumentSchema,
  diseaseEditSchema,
  diseaseRevision,
} from '../../src/modules/admin/management.types.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { memoryRepository } from '../auth/helpers.js';
import { testEnvironment, silentLogger, withServer } from '../foundation/helpers.js';
import { knowledgeDraft, memoryManagement } from './management.helpers.js';

test('knowledge validation rejects classifier edits, missing approval/source, invalid size/date and invented versions', () => {
  const valid = knowledgeDraft();
  for (const update of [
    { classLabels: ['renamed'] },
    { diseaseSlug: 'renamed-class' },
    { version: 99 },
    { expectedVersion: -1 },
    { approved: false },
    { source: { ...valid.source, url: 'http://example.invalid' } },
    { source: { ...valid.source, retrievedAt: '2026-02-30' } },
    { content: 'x'.repeat(4001) },
    { content: '\ud800' },
    { reviewNote: 'short' },
  ])
    assert.equal(draftDocumentSchema.safeParse({ ...valid, ...update }).success, false);
  assert.equal(
    diseaseEditSchema.safeParse({
      name: 'Display',
      scientificName: null,
      description: 'Synthetic',
      status: 'ACTIVE',
      expectedRevision: 'a'.repeat(64),
      slug: 'renamed',
    }).success,
    false,
  );
});
test('server stamps actor/review/version; immutable new drafts and provider failure never overwrite old content', async () => {
  const memory = memoryManagement(),
    actor = randomUUID(),
    request = randomUUID();
  const service = createManagementService(memory.repository, memory.indexer);
  const first = await service.createDraft(knowledgeDraft(), actor, request);
  assert.equal(first.version, 1);
  assert.equal(first.status, 'DRAFT');
  const original = memory.rows[0]?.content;
  const second = await service.createDraft(
    { ...knowledgeDraft(), expectedVersion: 1, content: 'Synthetic second reviewed revision.' },
    actor,
    request,
  );
  assert.equal(second.version, 2);
  assert.equal(memory.rows[0]?.content, original);
  await assert.rejects(
    service.createDraft(knowledgeDraft(), actor, request),
    (error) => (error as { code: string }).code === 'CONFLICT',
  );
  memory.setFail(true);
  await assert.rejects(
    service.createDraft({ ...knowledgeDraft(), expectedVersion: 2 }, actor, request),
  );
  assert.equal(memory.rows.length, 2);
  await assert.rejects(service.index(second.id, actor, request));
  assert.equal(memory.rows[1]?.status, 'DRAFT');
  assert.ok(!JSON.stringify(await service.document(first.id)).includes('retrievalIdentity'));
});
test('prepared metadata and index receipt mismatches fail closed before persistence', async () => {
  const memory = memoryManagement();
  const good = memory.indexer.prepare;
  memory.indexer.prepare = async (input) => ({
    ...(await good(input)),
    contentHash: '0'.repeat(64),
  });
  const service = createManagementService(memory.repository, memory.indexer);
  await assert.rejects(
    service.createDraft(knowledgeDraft(), randomUUID(), randomUUID()),
    (error) => (error as { code: string }).code === 'KNOWLEDGE_INVALID_RESPONSE',
  );
  assert.equal(memory.rows.length, 0);
  memory.indexer.prepare = good;
  const row = await service.createDraft(knowledgeDraft(), randomUUID(), randomUUID());
  const index = memory.indexer.index;
  memory.indexer.index = async (...args) => ({
    ...(await index(...args)),
    documentId: randomUUID(),
  });
  await assert.rejects(
    service.index(row.id, randomUUID(), randomUUID()),
    (error) => (error as { code: string }).code === 'KNOWLEDGE_INVALID_RESPONSE',
  );
});
test('display edits do not mutate fixed classifier label/slugs and revision hashes cover fields', async () => {
  const memory = memoryManagement();
  const before = diseaseRevision(memory.disease);
  assert.notEqual(before, diseaseRevision({ ...memory.disease, name: 'Changed display' }));
  const response = await createManagementService(memory.repository, memory.indexer).diseases();
  assert.equal(response.classMappingEditable, false);
  assert.equal(response.items[0]?.literalLabel, 'Common_Rust');
  assert.equal(response.items[0]?.slug, 'common-rust');
});

async function fixture() {
  const environment = { ...testEnvironment, KNOWLEDGE_RATE_LIMIT_MAX: 1000 };
  const auth = memoryRepository(),
    tokens = createAuthService(environment, auth.repository);
  const credentials = {
    email: 'admin-management@example.invalid',
    password: 'synthetic isolated credentials',
  };
  await tokens.createAdmin(credentials);
  const admin = await tokens.login(credentials);
  const farmerInput = { ...credentials, email: 'farmer-management@example.invalid' };
  await tokens.register(farmerInput);
  const farmer = await tokens.login(farmerInput);
  const memory = memoryManagement(),
    management = createManagementService(memory.repository, memory.indexer);
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
    undefined,
    management,
  );
  return { app, memory, admin, farmer, tokens };
}
const routes = [
  ['GET', '/diseases'],
  ['PATCH', '/diseases/common-rust'],
  ['GET', '/documents'],
  ['POST', '/documents'],
  ['GET', `/documents/${randomUUID()}`],
  ['POST', `/documents/${randomUUID()}/index`],
  ['PATCH', `/documents/${randomUUID()}/status`],
] as const;
test('all Admin knowledge management endpoints deny guests, FARMER and revoked ADMIN tokens', async () => {
  const f = await fixture();
  await withServer(f.app, async (base) => {
    for (const [method, path] of routes)
      for (const [token, status] of [
        [undefined, 401],
        [f.farmer.accessToken, 403],
        ['invalid', 401],
      ] as const) {
        const response = await fetch(`${base}/api/v1/admin/knowledge${path}`, {
          method,
          headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        });
        assert.equal(response.status, status, method + path);
        assert.equal(response.headers.get('cache-control'), 'no-store');
      }
    await f.tokens.logout(f.admin.refreshToken);
    assert.equal(
      (
        await fetch(`${base}/api/v1/admin/knowledge/diseases`, {
          headers: { Authorization: `Bearer ${f.admin.accessToken}` },
        })
      ).status,
      401,
    );
    assert.equal(f.memory.writes.length, 0);
  });
});
test('Admin draft endpoint validates JSON and stamps its own actor; source/model secrets do not leak', async () => {
  const f = await fixture();
  await withServer(f.app, async (base) => {
    const headers = {
      Authorization: `Bearer ${f.admin.accessToken}`,
      'Content-Type': 'application/json',
    };
    const response = await fetch(`${base}/api/v1/admin/knowledge/documents`, {
      method: 'POST',
      headers,
      body: JSON.stringify(knowledgeDraft()),
    });
    assert.equal(response.status, 201);
    const text = await response.text();
    assert.ok(text.includes('DRAFT'));
    assert.ok(!text.includes('reviewedBy'));
    assert.ok(!text.includes('embedding'));
    for (const update of [
      { actorId: randomUUID() },
      { classLabels: ['changed'] },
      { approved: false },
    ])
      assert.equal(
        (
          await fetch(`${base}/api/v1/admin/knowledge/documents`, {
            method: 'POST',
            headers,
            body: JSON.stringify({ ...knowledgeDraft(), ...update }),
          })
        ).status,
        400,
      );
    assert.equal(
      (
        await fetch(`${base}/api/v1/admin/knowledge/documents`, {
          method: 'POST',
          headers: { Authorization: headers.Authorization, 'Content-Type': 'text/plain' },
          body: '{}',
        })
      ).status,
      415,
    );
    const principal = await f.tokens.authenticate(f.admin.accessToken);
    assert.ok(JSON.stringify(f.memory.writes).includes(principal.userId));
  });
});
