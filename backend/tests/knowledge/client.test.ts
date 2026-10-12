import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { test } from 'node:test';
import { AppError, type ErrorCode } from '../../src/errors/app-error.js';
import { createKnowledgeClient } from '../../src/modules/knowledge/knowledge.client.js';
import type { KnowledgeSearch } from '../../src/modules/knowledge/knowledge.types.js';
import { retrieval } from './helpers.js';

const configuration = {
  AI_SERVICE_URL: 'http://127.0.0.1:8000',
  AI_SERVICE_TOKEN: randomBytes(32).toString('base64url'),
  AI_SERVICE_TIMEOUT_MS: 1000,
};
const input: KnowledgeSearch = { query: 'Common rust symptoms', topK: 3 };
const envelope = (data: unknown = retrieval()) => ({
  success: true,
  data,
  meta: { requestId: randomUUID() },
});
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
const codeIs = (code: ErrorCode) => (error: unknown) => {
  assert.ok(error instanceof AppError);
  assert.equal(error.code, code);
  assert.ok(!error.message.includes(configuration.AI_SERVICE_URL));
  assert.ok(!error.message.includes(configuration.AI_SERVICE_TOKEN));
  assert.ok(!error.message.includes('private-provider-details'));
  assert.ok(!('cause' in error));
  return true;
};

test('retrieval client uses only the configured endpoint, JSON filters and server credential', async () => {
  const expected = retrieval();
  const query: KnowledgeSearch = {
    ...input,
    query: 'Leaf symptoms: https://arbitrary.example/private',
    diseaseLabel: 'Common_Rust',
    knowledgeType: 'SYMPTOMS',
    documentVersion: 1,
    topK: 1,
  };
  let calls = 0;
  const client = createKnowledgeClient(configuration, async (url, options) => {
    calls++;
    assert.equal(String(url), 'http://127.0.0.1:8000/api/v1/retrieve');
    assert.equal(options?.method, 'POST');
    assert.equal(options?.redirect, 'manual');
    assert.equal(typeof options?.body, 'string');
    assert.deepEqual(JSON.parse(String(options?.body)), query);
    const headers = new Headers(options?.headers);
    assert.equal(headers.get('Authorization'), `Bearer ${configuration.AI_SERVICE_TOKEN}`);
    assert.equal(headers.get('Content-Type'), 'application/json');
    assert.equal(headers.get('Accept-Encoding'), 'identity');
    assert.equal(
      Number(headers.get('Content-Length')),
      Buffer.byteLength(String(options?.body), 'utf8'),
    );
    return json(envelope(expected));
  });
  assert.equal(client.enabled, true);
  assert.deepEqual(await client.search(query), expected);
  assert.equal(calls, 1);
});

test('disabled retrieval makes no network call and optional local credentials are not invented', async () => {
  const disabled = createKnowledgeClient(
    { ...configuration, AI_SERVICE_URL: '', AI_SERVICE_TOKEN: '' },
    async () => {
      assert.fail('Disabled retrieval must not open a network call.');
    },
  );
  assert.equal(disabled.enabled, false);
  await assert.rejects(disabled.search(input), codeIs('KNOWLEDGE_UNAVAILABLE'));
  const local = createKnowledgeClient(
    { ...configuration, AI_SERVICE_TOKEN: '' },
    async (_url, options) => {
      assert.equal(new Headers(options?.headers).has('Authorization'), false);
      return json(envelope());
    },
  );
  assert.equal((await local.search(input)).status, 'MATCHES');
});

test('no-match results remain evidence candidates and public metadata drops private fields', async () => {
  const data = retrieval();
  const chunk = data.chunks[0];
  assert.ok(chunk);
  const wire = {
    ...data,
    chunks: [
      {
        ...chunk,
        metadata: {
          ...chunk.metadata,
          providerToken: 'private-provider-details',
          vector: [1, 2],
          curation: { ...chunk.metadata.curation, internalPath: '/private/dataset' },
        },
      },
    ],
  };
  const result = await createKnowledgeClient(configuration, async () =>
    json(envelope(wire)),
  ).search(input);
  assert.deepEqual(result, data);
  const empty = { ...data, status: 'NO_MATCHES', chunks: [] };
  const noMatch = await createKnowledgeClient(configuration, async () =>
    json(envelope(empty)),
  ).search(input);
  assert.equal(noMatch.status, 'NO_MATCHES');
  assert.equal(noMatch.evidencePolicy, 'CANDIDATES_ONLY');
});

test('response schema rejects invalid identity, ranking, provenance and result consistency', async () => {
  const data = retrieval();
  const first = data.chunks[0];
  assert.ok(first);
  const invalid: unknown[] = [
    { ...data, status: 'GROUNDED' },
    { ...data, status: 'NO_MATCHES' },
    { ...data, chunks: [] },
    { ...data, answer: 'invented agricultural advice' },
    { ...data, embeddingDimensions: 127 },
    { ...data, embeddingDimensions: 3073 },
    { ...data, embeddingVersion: '' },
    { ...data, retrievalVersion: 'arbitrary' },
    { ...data, evidencePolicy: 'CERTAIN' },
    { ...data, chunks: [first, first] },
    { ...data, chunks: [first, { ...first, chunkId: randomUUID(), similarity: 0.7 }] },
    { ...data, chunks: [first, { ...first, chunkId: randomUUID(), similarity: 0.99 }] },
  ];
  for (const mutation of [
    { documentId: 'not-a-uuid' },
    { documentVersion: 0 },
    { chunkId: 'not-a-uuid' },
    { chunkIndex: -1 },
    { content: '' },
    { content: 'x'.repeat(12_001) },
    { diseaseLabel: 'common_rust' },
    { knowledgeType: 'TREATMENT' },
    { similarity: 1.01 },
    { similarity: -1.01 },
    { similarity: '0.8' },
    { metadata: [] },
    { metadata: { contentHash: 'bad' } },
    { metadata: { start: 4, end: 3 } },
    { embedding: [1, 2] },
    { source: { ...first.source, url: 'javascript:alert(1)' } },
    { source: { ...first.source, url: 'https://user:secret@example.com' } },
    { source: { ...first.source, publishedAt: '2026-02-30' } },
    { source: { ...first.source, retrievedAt: 'unknown' } },
    { source: { ...first.source, rights: '' } },
    { source: { ...first.source, privateKey: 'private-provider-details' } },
  ])
    invalid.push({ ...data, chunks: [{ ...first, ...mutation }] });
  for (const body of invalid)
    await assert.rejects(
      createKnowledgeClient(configuration, async () => json(envelope(body))).search(input),
      codeIs('KNOWLEDGE_INVALID_RESPONSE'),
    );
});

test('internal results must honor class/topic/version filters and requested topK', async () => {
  const data = retrieval();
  for (const query of [
    { ...input, diseaseLabel: 'Healthy' as const },
    { ...input, knowledgeType: 'CAUSES' as const },
    { ...input, documentVersion: 2 },
  ])
    await assert.rejects(
      createKnowledgeClient(configuration, async () => json(envelope(data))).search(query),
      codeIs('KNOWLEDGE_INVALID_RESPONSE'),
    );
  const first = data.chunks[0];
  assert.ok(first);
  await assert.rejects(
    createKnowledgeClient(configuration, async () =>
      json(
        envelope({
          ...data,
          chunks: [first, { ...first, chunkId: randomUUID(), chunkIndex: 1, similarity: 0.7 }],
        }),
      ),
    ).search({ ...input, topK: 1 }),
    codeIs('KNOWLEDGE_INVALID_RESPONSE'),
  );
});

test('wire envelopes, UUID correlation, redirects, content type and UTF-8 are strict', async () => {
  const data = retrieval();
  for (const response of [
    json(data),
    json({ ...envelope(), meta: { requestId: 'bad' } }),
    json({ ...envelope(), privateConfig: 'private-provider-details' }),
    json(envelope(), 201),
    new Response(null, { status: 307, headers: { Location: 'https://arbitrary.example' } }),
    new Response('not-json', { headers: { 'Content-Type': 'application/json' } }),
    new Response('private-provider-details', { headers: { 'Content-Type': 'text/html' } }),
    new Response(new Uint8Array([255, 254]), { headers: { 'Content-Type': 'application/json' } }),
    new Response(JSON.stringify(envelope()), {
      headers: { 'Content-Type': 'application/json', 'Content-Encoding': 'gzip' },
    }),
  ])
    await assert.rejects(
      createKnowledgeClient(configuration, async () => response).search(input),
      codeIs('KNOWLEDGE_INVALID_RESPONSE'),
    );
});

test('provider and transport failures produce safe status mappings without causes or private details', async () => {
  for (const status of [401, 403, 422, 429, 500, 502, 503, 408, 504]) {
    const failure = {
      success: false,
      error: { code: 'RETRIEVAL_FAILED', message: 'private-provider-details', issues: [] },
      meta: { requestId: randomUUID() },
    };
    await assert.rejects(
      createKnowledgeClient(configuration, async () => json(failure, status)).search(input),
      codeIs([408, 504].includes(status) ? 'KNOWLEDGE_TIMEOUT' : 'KNOWLEDGE_UNAVAILABLE'),
    );
  }
  await assert.rejects(
    createKnowledgeClient(configuration, async () => {
      throw new Error(`private-provider-details ${configuration.AI_SERVICE_TOKEN}`);
    }).search(input),
    codeIs('KNOWLEDGE_UNAVAILABLE'),
  );
  await assert.rejects(
    createKnowledgeClient(configuration, async () =>
      json({ error: 'private-provider-details' }, 503),
    ).search(input),
    codeIs('KNOWLEDGE_INVALID_RESPONSE'),
  );
});

test('response length and streamed bytes are bounded and failed bodies are cancelled', async () => {
  for (const length of ['131073', '-1', 'bad', '999999999999', '1']) {
    const response = json(envelope());
    response.headers.set('Content-Length', length);
    await assert.rejects(
      createKnowledgeClient(configuration, async () => response).search(input),
      codeIs('KNOWLEDGE_INVALID_RESPONSE'),
    );
  }
  let cancelled = false;
  const oversized = new Response(
    new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(131073));
      },
      cancel() {
        cancelled = true;
      },
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  await assert.rejects(
    createKnowledgeClient(configuration, async () => oversized).search(input),
    codeIs('KNOWLEDGE_INVALID_RESPONSE'),
  );
  assert.equal(cancelled, true);
});

test('one deadline covers both transport and a stalled response stream', async () => {
  const short = { ...configuration, AI_SERVICE_TIMEOUT_MS: 30 };
  let signal: AbortSignal | null | undefined;
  await assert.rejects(
    createKnowledgeClient(short, async (_url, options) => {
      signal = options?.signal;
      return new Promise<Response>(() => {});
    }).search(input),
    codeIs('KNOWLEDGE_TIMEOUT'),
  );
  assert.equal(signal?.aborted, true);
  let cancelled = false;
  await assert.rejects(
    createKnowledgeClient(
      short,
      async () =>
        new Response(
          new ReadableStream<Uint8Array>({
            start(controller) {
              controller.enqueue(new TextEncoder().encode('{'));
            },
            cancel() {
              cancelled = true;
            },
          }),
          { headers: { 'Content-Type': 'application/json' } },
        ),
    ).search(input),
    codeIs('KNOWLEDGE_TIMEOUT'),
  );
  assert.equal(cancelled, true);
});

test('native HTTP transport sends JSON correctly and refuses a redirect without credential forwarding', async () => {
  const result = retrieval();
  let redirect = false;
  let requests = 0;
  let destinationRequests = 0;
  const server = createServer(async (request, response) => {
    if (request.url === '/must-not-fetch') {
      destinationRequests++;
      response.end();
      return;
    }
    requests++;
    assert.equal(request.url, '/api/v1/retrieve');
    assert.equal(request.headers.authorization, `Bearer ${configuration.AI_SERVICE_TOKEN}`);
    const chunks: Buffer[] = [];
    for await (const chunk of request) chunks.push(Buffer.from(chunk));
    assert.deepEqual(JSON.parse(Buffer.concat(chunks).toString('utf8')), input);
    if (redirect) response.writeHead(307, { Location: '/must-not-fetch' });
    else response.writeHead(200, { 'Content-Type': 'application/json' });
    response.end(redirect ? undefined : JSON.stringify(envelope(result)));
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address() as AddressInfo;
    const client = createKnowledgeClient({
      ...configuration,
      AI_SERVICE_URL: `http://127.0.0.1:${address.port}`,
    });
    assert.deepEqual(await client.search(input), result);
    redirect = true;
    await assert.rejects(client.search(input), codeIs('KNOWLEDGE_INVALID_RESPONSE'));
    assert.equal(destinationRequests, 0);
    assert.equal(requests, 2);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
});
