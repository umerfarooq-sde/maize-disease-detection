import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import { parseEnvironment } from '../../src/config/environment.js';
import { AppError } from '../../src/errors/app-error.js';
import { createKnowledgeClient } from '../../src/modules/knowledge/knowledge.client.js';
import { createKnowledgeService } from '../../src/modules/knowledge/knowledge.service.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { fakeInference, fakeStorage, memoryScans } from '../scans/helpers.js';
import { disease, memoryKnowledge } from './helpers.js';

function fixture(limit = 100) {
  const knowledge = memoryKnowledge();
  const environment = { ...testEnvironment, KNOWLEDGE_RATE_LIMIT_MAX: limit };
  const service = createKnowledgeService(knowledge.repository, knowledge.client);
  const app = createApp(
    environment,
    silentLogger,
    { async checkDatabase() {} },
    memoryRepository().repository,
    createScanService(
      memoryScans().repository,
      fakeStorage().storage,
      silentLogger,
      fakeInference().client,
    ),
    service,
  );
  return { ...knowledge, service, app };
}
async function responseBody(response: Response, status = 200, code?: string) {
  assert.equal(response.status, status);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const body = (await response.json()) as {
    success: boolean;
    data?: unknown;
    error?: { code: string; message: string };
    requestId: string;
  };
  assert.equal(body.requestId, response.headers.get('x-request-id'));
  assert.equal(body.success, status < 400);
  if (code) assert.equal(body.error?.code, code);
  assert.ok(!JSON.stringify(body).includes('private-'));
  assert.ok(!JSON.stringify(body).includes('stack'));
  return body;
}
const post = (url: string, body: unknown, query = '') =>
  fetch(`${url}/api/v1/knowledge/search${query}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

test('public disease list/detail expose only active safe fields and attributed active sections', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    const list = await responseBody(await fetch(`${url}/api/v1/diseases`));
    assert.deepEqual(list.data, {
      items: [
        disease,
        {
          slug: 'healthy',
          name: 'Healthy / scouting context',
          scientificName: null,
          description: 'Synthetic scouting context.',
        },
      ],
    });
    const detail = await responseBody(await fetch(`${url}/api/v1/diseases/common-rust`));
    const data = detail.data as {
      sections: { documentKey: string; documentVersion: number; source: unknown }[];
    };
    assert.equal(data.sections.length, 1);
    assert.equal(data.sections[0]?.documentKey, 'maize-common-rust-symptoms');
    assert.equal(data.sections[0]?.documentVersion, 1);
    assert.ok(data.sections[0]?.source);
    for (const name of ['createdById', 'metadata', 'embedding', 'passwordHash', 'status'])
      assert.ok(!JSON.stringify(detail).includes(`"${name}"`));
    const healthy = await responseBody(await fetch(`${url}/api/v1/diseases/healthy`));
    assert.deepEqual((healthy.data as { sections: unknown[] }).sections, []);
    for (const slug of ['inactive-disease', 'draft-disease', 'unknown-disease'])
      await responseBody(await fetch(`${url}/api/v1/diseases/${slug}`), 404, 'NOT_FOUND');
  });
});

test('search forwards validated optional filters and defaults once and preserves candidate semantics', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    const response = await responseBody(await post(url, { query: '  Common rust symptoms  ' }));
    assert.deepEqual(response.data, setup.result);
    assert.deepEqual(setup.searches[0], { query: 'Common rust symptoms', topK: 3 });
    await responseBody(
      await post(url, {
        query: 'Leaf disease symptoms',
        diseaseLabel: 'Common_Rust',
        knowledgeType: 'SYMPTOMS',
        documentVersion: 1,
        topK: 10,
      }),
    );
    assert.deepEqual(setup.searches[1], {
      query: 'Leaf disease symptoms',
      diseaseLabel: 'Common_Rust',
      knowledgeType: 'SYMPTOMS',
      documentVersion: 1,
      topK: 10,
    });
    setup.client.search = async () => ({ ...setup.result, status: 'NO_MATCHES', chunks: [] });
    const empty = await responseBody(
      await post(url, {
        query: 'Healthy treatment',
        diseaseLabel: 'Healthy',
        knowledgeType: 'MANAGEMENT',
      }),
    );
    assert.equal((empty.data as { status: string }).status, 'NO_MATCHES');
    assert.equal((response.data as { evidencePolicy: string }).evidencePolicy, 'CANDIDATES_ONLY');
    assert.deepEqual(Object.keys(response).sort(), ['data', 'requestId', 'success']);
  });
});

test('strict request validation rejects unknown ownership, labels, types, sizes and route queries before searching', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    for (const body of [
      {},
      { query: 'ab' },
      { query: '   ' },
      { query: 'a'.repeat(1001) },
      { query: ['abc'] },
      { query: 'symptoms', diseaseLabel: 'common_rust' },
      { query: 'symptoms', diseaseLabel: 'OTHER' },
      { query: 'symptoms', knowledgeType: 'TREATMENT' },
      { query: 'symptoms', documentVersion: 0 },
      { query: 'symptoms', documentVersion: '1' },
      { query: 'symptoms', documentVersion: 1.5 },
      { query: 'symptoms', topK: 0 },
      { query: 'symptoms', topK: 11 },
      { query: 'symptoms', topK: '3' },
      { query: 'symptoms', userId: 'private-owner' },
      { query: 'symptoms', status: 'DRAFT' },
    ])
      await responseBody(await post(url, body), 400, 'VALIDATION_ERROR');
    await responseBody(await post(url, { query: 'symptoms' }, '?topK=1'), 400, 'VALIDATION_ERROR');
    await responseBody(
      await fetch(`${url}/api/v1/diseases?include=drafts`),
      400,
      'VALIDATION_ERROR',
    );
    await responseBody(
      await fetch(`${url}/api/v1/diseases/common-rust?version=1`),
      400,
      'VALIDATION_ERROR',
    );
    await responseBody(await fetch(`${url}/api/v1/diseases/Common_Rust`), 400, 'VALIDATION_ERROR');
    assert.equal(setup.searches.length, 0);
    await responseBody(await post(url, { query: 'abc', topK: 1 }), 200);
  });
});

test('search requires JSON and enforces the configured shared knowledge rate limit with safe responses', async () => {
  const setup = fixture(2);
  await withServer(setup.app, async (url) => {
    await responseBody(
      await fetch(`${url}/api/v1/knowledge/search`, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain' },
        body: 'symptoms',
      }),
      415,
      'UNSUPPORTED_MEDIA_TYPE',
    );
    await responseBody(await fetch(`${url}/api/v1/diseases`));
    await responseBody(await post(url, { query: 'symptoms' }), 429, 'RATE_LIMITED');
    assert.equal(setup.searches.length, 0);
  });
});

test('safe knowledge/database failures use centralized public status codes without upstream causes', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    for (const [code, status] of [
      ['KNOWLEDGE_UNAVAILABLE', 503],
      ['KNOWLEDGE_TIMEOUT', 504],
      ['KNOWLEDGE_INVALID_RESPONSE', 502],
    ] as const) {
      setup.client.search = async () => {
        throw new AppError(code);
      };
      await responseBody(await post(url, { query: 'symptoms' }), status, code);
    }
    setup.repository.listDiseases = async () => {
      throw new Error('private-database-credentials');
    };
    await responseBody(await fetch(`${url}/api/v1/diseases`), 500, 'INTERNAL_SERVER_ERROR');
  });
});

test('query admission matches Python Unicode, control-character and UTF-8 byte boundaries', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    for (const query of [
      '🌽🌽',
      '\u0085ab\u0085',
      'abc\u0000',
      'abc\rdef',
      '\ud800ab',
      'ع'.repeat(901),
    ])
      await responseBody(await post(url, { query }), 400, 'VALIDATION_ERROR');
    assert.equal(setup.searches.length, 0);
    for (const query of ['🌽🌽🌽', 'ع'.repeat(900), 'a'.repeat(1000), 'abc\ndef\tghi'])
      await responseBody(await post(url, { query }));
    assert.deepEqual(
      setup.searches.map((entry) => entry.query),
      ['🌽🌽🌽', 'ع'.repeat(900), 'a'.repeat(1000), 'abc\ndef\tghi'],
    );
  });
});

test('environment bounds knowledge rate settings and disabled AI leaves sourced disease browsing available', async () => {
  assert.equal(testEnvironment.KNOWLEDGE_RATE_LIMIT_MAX, 20);
  for (const invalid of ['0', '-1', '1001', 'bad'])
    assert.throws(
      () =>
        parseEnvironment({
          DATABASE_URL: testEnvironment.DATABASE_URL,
          JWT_SECRET: testEnvironment.JWT_SECRET,
          JWT_REFRESH_SECRET: testEnvironment.JWT_REFRESH_SECRET,
          KNOWLEDGE_RATE_LIMIT_MAX: invalid,
        }),
      /KNOWLEDGE_RATE_LIMIT_MAX/,
    );
  const setup = memoryKnowledge();
  const service = createKnowledgeService(setup.repository, createKnowledgeClient(testEnvironment));
  assert.equal((await service.listDiseases()).items.length, 2);
  await assert.rejects(
    service.search({ query: 'symptoms', topK: 3 }),
    (error: unknown) => error instanceof AppError && error.code === 'KNOWLEDGE_UNAVAILABLE',
  );
});
