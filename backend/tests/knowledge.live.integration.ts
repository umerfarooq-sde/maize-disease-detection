import assert from 'node:assert/strict';
import { once } from 'node:events';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import { createApp } from '../src/app.js';
import { loadEnvironment } from '../src/config/environment.js';
import { createLogger } from '../src/config/logger.js';
import { getDatabaseClient } from '../src/database/client.js';
import { operationsFor } from '../src/modules/admin/operations.service.js';
import { silentLogger } from './foundation/helpers.js';
import { retrievalResultSchema } from '../src/modules/knowledge/knowledge.types.js';

test('real public Node -> authenticated FastAPI -> Google embeddings -> pgvector contracts', {
  skip: process.env['RUN_LIVE_KNOWLEDGE'] !== '1',
}, async () => {
  const environment = {
    ...loadEnvironment(),
    AI_SERVICE_TIMEOUT_MS: 20000,
    KNOWLEDGE_RATE_LIMIT_MAX: 40,
  };
  const database = getDatabaseClient(environment.DATABASE_URL);
  const recordedBefore = await database.aiOperation.count({
    where: { scope: 'NODE', operation: 'RETRIEVAL' },
  });
  const app = createApp(environment, createLogger({ ...environment, LOG_LEVEL: 'error' }), {
    async checkDatabase() {
      await database.$queryRaw`SELECT 1`;
    },
  });
  const server = app.listen(0, '127.0.0.1');
  try {
    await once(server, 'listening');
    const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}/api/v1`;
    const list = await fetch(`${base}/diseases`);
    assert.equal(list.status, 200);
    const catalog = (await list.json()) as { data: { items: { slug: string }[] } };
    assert.equal(catalog.data.items.length, 4);
    for (const [slug, label, sections] of [
      ['common-rust', 'Common_Rust', 7],
      ['gray-leaf-spot', 'Gray_Leaf_Spot', 7],
      ['northern-corn-leaf-blight', 'Northern_Corn_Leaf_Blight', 7],
      ['healthy', 'Healthy', 4],
    ] as const) {
      const detail = await fetch(`${base}/diseases/${slug}`);
      assert.equal(detail.status, 200);
      const document = (await detail.json()) as {
        data: { sections: { source: { url: string }; documentVersion: number }[] };
      };
      assert.equal(document.data.sections.length, sections);
      assert.ok(
        document.data.sections.every(
          (section) => section.source.url.startsWith('https://') && section.documentVersion === 1,
        ),
      );
      const result = await fetch(`${base}/knowledge/search`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: 'What should I look for when scouting maize leaves?',
          diseaseLabel: label,
          knowledgeType: 'SYMPTOMS',
          topK: 3,
        }),
      });
      assert.equal(result.status, 200);
      assert.equal(result.headers.get('cache-control'), 'no-store');
      const payload = (await result.json()) as { data: unknown };
      const retrieval = retrievalResultSchema.parse(payload.data);
      assert.equal(retrieval.status, 'MATCHES');
      assert.equal(retrieval.chunks.length, 1);
      assert.equal(retrieval.chunks[0]?.diseaseLabel, label);
      assert.equal(retrieval.embeddingDimensions, 768);
      assert.equal(retrieval.evidencePolicy, 'CANDIDATES_ONLY');
    }
    const absent = await fetch(`${base}/knowledge/search`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query: 'What treatment does a healthy crop need?',
        diseaseLabel: 'Healthy',
        knowledgeType: 'MANAGEMENT',
      }),
    });
    assert.equal(absent.status, 200);
    assert.equal(((await absent.json()) as { data: { status: string } }).data.status, 'NO_MATCHES');
    await operationsFor(database, silentLogger).flush();
    assert.equal(
      await database.aiOperation.count({ where: { scope: 'NODE', operation: 'RETRIEVAL' } }),
      recordedBefore + 5,
      'Every observed successful retrieval must be drained before disconnecting this fixture database.',
    );
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
    await (app.locals.flushOperationalEvents as () => Promise<void>)();
    await database.$disconnect();
  }
});
