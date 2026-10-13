import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { test } from 'node:test';
import { AppError, type ErrorCode } from '../../src/errors/app-error.js';
import { createGenerationClient } from '../../src/modules/generation/generation.client.js';
import { answer, prediction } from './helpers.js';

const configuration = {
  AI_SERVICE_URL: 'http://127.0.0.1:8000',
  AI_SERVICE_TOKEN: randomBytes(32).toString('base64url'),
  GENERATION_TIMEOUT_MS: 1000,
};
const question = {
  question: 'Common rust overview',
  diseaseLabel: 'Common_Rust' as const,
  knowledgeType: 'OVERVIEW' as const,
};
const envelope = (data: unknown = answer()) => ({
  success: true,
  data,
  meta: { requestId: randomUUID() },
});
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const codeIs = (code: ErrorCode) => (error: unknown) => {
  assert.ok(error instanceof AppError);
  assert.equal(error.code, code);
  for (const value of [
    'private-provider-message',
    configuration.AI_SERVICE_URL,
    configuration.AI_SERVICE_TOKEN,
  ])
    assert.ok(!error.message.includes(value));
  assert.ok(!('cause' in error));
  return true;
};

test('generation client sends questions/context only to two fixed JSON endpoints with server authentication', async () => {
  const context = prediction();
  const questionAnswer = answer();
  const explanation = answer(context);
  let calls = 0;
  const client = createGenerationClient(configuration, async (url, options) => {
    calls++;
    assert.equal(
      String(url),
      `${configuration.AI_SERVICE_URL}/api/v1/${calls === 1 ? 'generate' : 'explain'}`,
    );
    assert.equal(options?.method, 'POST');
    assert.equal(options?.redirect, 'manual');
    const headers = new Headers(options?.headers);
    assert.equal(headers.get('Authorization'), `Bearer ${configuration.AI_SERVICE_TOKEN}`);
    assert.equal(headers.get('Content-Type'), 'application/json');
    assert.equal(headers.get('Accept-Encoding'), 'identity');
    assert.equal(
      Number(headers.get('Content-Length')),
      Buffer.byteLength(String(options?.body), 'utf8'),
    );
    assert.deepEqual(
      JSON.parse(String(options?.body)),
      calls === 1 ? question : { prediction: context },
    );
    return json(envelope(calls === 1 ? questionAnswer : explanation));
  });
  assert.deepEqual(await client.ask(question), questionAnswer);
  assert.deepEqual(await client.explain(context), explanation);
  assert.equal(calls, 2);
});

test('disabled generation is explicit and no network destination comes from a user question', async () => {
  const disabled = createGenerationClient({ ...configuration, AI_SERVICE_URL: '' }, async () =>
    assert.fail('disabled'),
  );
  assert.equal(disabled.enabled, false);
  await assert.rejects(disabled.ask(question), codeIs('GEN_UNAVAILABLE'));
  await assert.rejects(disabled.explain(prediction()), codeIs('GEN_UNAVAILABLE'));
  const client = createGenerationClient(configuration, async (url) => {
    assert.equal(String(url), `${configuration.AI_SERVICE_URL}/api/v1/generate`);
    return json(envelope());
  });
  await client.ask({ question: 'Fetch https://arbitrary.example/private' });
});

test('non-grounded outcomes contain no factual sections/sources and may honestly report provider use', async () => {
  for (const status of [
    'INSUFFICIENT_INFORMATION',
    'OUT_OF_SCOPE',
    'CONFLICTING_EVIDENCE',
  ] as const) {
    const data = {
      ...answer(),
      status,
      sections: [],
      sources: [],
      providerUsed: status === 'INSUFFICIENT_INFORMATION',
    };
    assert.deepEqual(
      await createGenerationClient(configuration, async () => json(envelope(data))).ask(question),
      data,
    );
  }
});

test('citation membership/usage, topic uniqueness and strict generated response structure are enforced', async () => {
  const data = answer();
  const section = data.sections[0];
  const source = data.sources[0];
  assert.ok(section && source);
  const invalid: unknown[] = [
    { ...data, status: 'CONFIDENT' },
    { ...data, status: 'OUT_OF_SCOPE' },
    { ...data, sections: [] },
    { ...data, sources: [] },
    { ...data, reason: 'mixedCase' },
    { ...data, message: ' ' },
    { ...data, providerUsed: 'true' },
    { ...data, generationModel: '' },
    { ...data, promptVersion: 'free-paraphrase-v1' },
    { ...data, contextPolicyVersion: 'unrestricted' },
    { ...data, reviewSetVersion: '' },
    { ...data, durationMs: -1 },
    { ...data, durationMs: 120001 },
    { ...data, internalApiKey: 'private-provider-message' },
    { ...data, sections: [section, section] },
    { ...data, sources: [source, source] },
    { ...data, sources: [source, { ...source, id: 'e2' }] },
    { ...data, sections: [{ ...section, items: [] }] },
    { ...data, sections: [{ ...section, items: [{ text: 'fact', sourceIds: [] }] }] },
    { ...data, sections: [{ ...section, items: [{ text: 'fact', sourceIds: ['e99'] }] }] },
    { ...data, sections: [{ ...section, items: [{ text: 'fact', sourceIds: ['e1', 'e1'] }] }] },
    { ...data, sections: [{ ...section, items: [{ text: 'x'.repeat(4001), sourceIds: ['e1'] }] }] },
    { ...data, sources: [{ ...source, documentId: 'bad' }] },
    { ...data, sources: [{ ...source, chunkIds: [] }] },
    { ...data, sources: [{ ...source, chunkIds: [source.chunkIds[0], source.chunkIds[0]] }] },
    { ...data, sources: [{ ...source, source: { ...source.source, url: 'javascript:alert(1)' } }] },
  ];
  for (const body of invalid)
    await assert.rejects(
      createGenerationClient(configuration, async () => json(envelope(body))).ask(question),
      codeIs('GEN_INVALID_RESPONSE'),
    );
  await assert.rejects(
    createGenerationClient(configuration, async () => json(envelope(data))).ask({
      ...question,
      knowledgeType: 'CAUSES',
    }),
    codeIs('GEN_INVALID_RESPONSE'),
  );
});

test('the provider cannot add ML context to public ask or change any persisted explanation field', async () => {
  const context = prediction();
  await assert.rejects(
    createGenerationClient(configuration, async () => json(envelope(answer(context)))).ask(
      question,
    ),
    codeIs('GEN_INVALID_RESPONSE'),
  );
  const data = answer(context);
  for (const mutation of [
    { predictedClass: 'Healthy' },
    { confidence: 0.81 },
    { modelVersion: 'other-model' },
    { preprocessingVersion: '2.0.0' },
    { predictionStatus: 'CONFIDENT', confidenceThreshold: 0.7, uncertaintyReason: null },
    { confidenceThreshold: 0.9, uncertaintyReason: 'BELOW_VALIDATION_THRESHOLD' },
  ])
    await assert.rejects(
      createGenerationClient(configuration, async () =>
        json(envelope({ ...data, classifierPrediction: { ...context, ...mutation } })),
      ).explain(context),
      codeIs('GEN_INVALID_RESPONSE'),
    );
  for (const change of [{ classifierPrediction: null }, { warnings: [] }])
    await assert.rejects(
      createGenerationClient(configuration, async () =>
        json(envelope({ ...data, ...change })),
      ).explain(context),
      codeIs('GEN_INVALID_RESPONSE'),
    );
  assert.deepEqual(
    await createGenerationClient(configuration, async () => json(envelope(data))).explain(context),
    data,
  );
});

test('wire envelopes, request UUID, UTF-8, content type/encoding and redirects fail closed', async () => {
  for (const response of [
    json(answer()),
    json({ ...envelope(), meta: { requestId: 'bad' } }),
    json({ ...envelope(), privatePath: '/private' }),
    json(envelope(), 201),
    new Response(null, { status: 302, headers: { Location: 'https://arbitrary.example' } }),
    new Response('not-json', { headers: { 'Content-Type': 'application/json' } }),
    new Response('private-provider-message', { headers: { 'Content-Type': 'text/html' } }),
    new Response(new Uint8Array([255, 254]), { headers: { 'Content-Type': 'application/json' } }),
    new Response(JSON.stringify(envelope()), {
      headers: { 'Content-Type': 'application/json', 'Content-Encoding': 'gzip' },
    }),
  ])
    await assert.rejects(
      createGenerationClient(configuration, async () => response).ask(question),
      codeIs('GEN_INVALID_RESPONSE'),
    );
});

test('provider/transport failures map to safe errors and never carry causes, secrets or raw messages', async () => {
  for (const status of [401, 403, 429, 500, 502, 503, 408, 504]) {
    const failure = {
      success: false,
      error: { code: 'GENERATION_UNAVAILABLE', message: 'private-provider-message', issues: [] },
      meta: { requestId: randomUUID() },
    };
    await assert.rejects(
      createGenerationClient(configuration, async () => json(failure, status)).ask(question),
      codeIs([408, 504].includes(status) ? 'GEN_TIMEOUT' : 'GEN_UNAVAILABLE'),
    );
  }
  await assert.rejects(
    createGenerationClient(configuration, async () => {
      throw new Error(configuration.AI_SERVICE_TOKEN);
    }).ask(question),
    codeIs('GEN_UNAVAILABLE'),
  );
  await assert.rejects(
    createGenerationClient(configuration, async () =>
      json({ error: 'private-provider-message' }, 503),
    ).ask(question),
    codeIs('GEN_INVALID_RESPONSE'),
  );
});

test('response limit checks declared lengths and streamed bytes, canceling oversized bodies', async () => {
  for (const length of ['131073', '-1', 'bad', '99999999999', '1']) {
    const response = json(envelope());
    response.headers.set('Content-Length', length);
    await assert.rejects(
      createGenerationClient(configuration, async () => response).ask(question),
      codeIs('GEN_INVALID_RESPONSE'),
    );
  }
  let cancelled = false;
  const response = new Response(
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
    createGenerationClient(configuration, async () => response).ask(question),
    codeIs('GEN_INVALID_RESPONSE'),
  );
  assert.equal(cancelled, true);
});

test('generation deadline aborts stalled transport and stalled streamed response bodies', async () => {
  const short = { ...configuration, GENERATION_TIMEOUT_MS: 30 };
  let signal: AbortSignal | null | undefined;
  await assert.rejects(
    createGenerationClient(short, async (_url, options) => {
      signal = options?.signal;
      return new Promise<Response>(() => {});
    }).ask(question),
    codeIs('GEN_TIMEOUT'),
  );
  assert.equal(signal?.aborted, true);
  let cancelled = false;
  await assert.rejects(
    createGenerationClient(
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
    ).ask(question),
    codeIs('GEN_TIMEOUT'),
  );
  assert.equal(cancelled, true);
});

test('native local HTTP sends trusted prediction JSON and refuses redirected credential forwarding', async () => {
  const context = prediction();
  const data = answer(context);
  let redirect = false;
  let destinationCalls = 0;
  const server = createServer(async (request, response) => {
    if (request.url === '/must-not-fetch') {
      destinationCalls++;
      response.end();
      return;
    }
    assert.equal(request.url, '/api/v1/explain');
    assert.equal(request.headers.authorization, `Bearer ${configuration.AI_SERVICE_TOKEN}`);
    const parts: Buffer[] = [];
    for await (const part of request) parts.push(Buffer.from(part));
    assert.deepEqual(JSON.parse(Buffer.concat(parts).toString('utf8')), { prediction: context });
    response.writeHead(
      redirect ? 307 : 200,
      redirect ? { Location: '/must-not-fetch' } : { 'Content-Type': 'application/json' },
    );
    response.end(redirect ? undefined : JSON.stringify(envelope(data)));
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address() as AddressInfo;
    const client = createGenerationClient({
      ...configuration,
      AI_SERVICE_URL: `http://127.0.0.1:${address.port}`,
    });
    assert.deepEqual(await client.explain(context), data);
    redirect = true;
    await assert.rejects(client.explain(context), codeIs('GEN_INVALID_RESPONSE'));
    assert.equal(destinationCalls, 0);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
});
