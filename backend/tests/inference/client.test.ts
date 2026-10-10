import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { test } from 'node:test';
import { AppError, type ErrorCode } from '../../src/errors/app-error.js';
import { createAiInferenceClient } from '../../src/modules/inference/inference.client.js';
import {
  diseaseLabels,
  type InferencePrediction,
} from '../../src/modules/inference/inference.types.js';
import type { ValidatedImage } from '../../src/modules/scans/scan.types.js';

const configuration = {
  AI_SERVICE_URL: 'http://127.0.0.1:8000',
  AI_SERVICE_TOKEN: randomBytes(32).toString('base64url'),
  AI_SERVICE_TIMEOUT_MS: 1000,
  AI_MODEL_VERSION: 'synthetic-model-v1',
  AI_PREPROCESSING_VERSION: '1.0.0',
};
const image: ValidatedImage = {
  bytes: Buffer.from('original-validated-encoded-image'),
  mimeType: 'image/png',
  width: 24,
  height: 24,
  orientation: 1,
};
const prediction = (): InferencePrediction => ({
  predictedClass: 'Healthy',
  confidence: 0.7,
  topProbabilities: [
    { className: 'Healthy', probability: 0.7 },
    { className: 'Common_Rust', probability: 0.2 },
    { className: 'Gray_Leaf_Spot', probability: 0.07 },
    { className: 'Northern_Corn_Leaf_Blight', probability: 0.03 },
  ],
  modelVersion: configuration.AI_MODEL_VERSION,
  preprocessingVersion: configuration.AI_PREPROCESSING_VERSION,
  inferenceDurationMs: 17.25,
  predictionStatus: 'LOW_CONFIDENCE',
  uncertaintyReason: 'THRESHOLD_UNCONFIGURED',
  confidenceThreshold: null,
});
const envelope = (data: unknown = prediction()) => ({
  success: true,
  data,
  meta: { requestId: randomUUID() },
});
const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const serviceError = (code: string) => ({
  success: false,
  error: { code, message: 'private-provider-message', issues: [] },
  meta: { requestId: randomUUID() },
});
const hasCode = (code: ErrorCode) => (error: unknown) => {
  assert.ok(error instanceof AppError);
  assert.equal(error.code, code);
  assert.ok(!error.message.includes('private-provider-message'));
  assert.ok(!error.message.includes(configuration.AI_SERVICE_TOKEN));
  assert.ok(!error.message.includes(configuration.AI_SERVICE_URL));
  assert.ok(!('cause' in error));
  return true;
};

test('dedicated client sends unchanged bytes and server credential only to the fixed internal route', async () => {
  let requests = 0;
  const client = createAiInferenceClient(configuration, async (input, options) => {
    requests++;
    assert.equal(String(input), 'http://127.0.0.1:8000/api/v1/predict?top_k=4');
    assert.equal(options?.method, 'POST');
    assert.equal(options?.redirect, 'manual');
    const headers = new Headers(options?.headers);
    assert.equal(headers.get('Authorization'), `Bearer ${configuration.AI_SERVICE_TOKEN}`);
    assert.equal(headers.get('Content-Type'), image.mimeType);
    assert.equal(headers.get('Content-Length'), String(image.bytes.length));
    assert.ok(options?.body instanceof Uint8Array);
    assert.deepEqual(Buffer.from(options.body), image.bytes);
    return jsonResponse(envelope());
  });
  assert.equal(client.enabled, true);
  assert.deepEqual(await client.predict(image), prediction());
  assert.equal(requests, 1);
});

test('disabled integration is explicit and never opens a network request', async () => {
  const client = createAiInferenceClient(
    {
      ...configuration,
      AI_SERVICE_URL: '',
      AI_SERVICE_TOKEN: '',
      AI_MODEL_VERSION: '',
      AI_PREPROCESSING_VERSION: '',
    },
    async () => {
      assert.fail('Disabled integration must never call the transport.');
    },
  );
  assert.equal(client.enabled, false);
  await assert.rejects(client.predict(image), hasCode('INFERENCE_UNAVAILABLE'));
});

test('all four literal classes are admitted with stable complete probabilities', async () => {
  for (const label of diseaseLabels) {
    const data = prediction();
    data.predictedClass = label;
    data.confidence = 0.7;
    data.topProbabilities = [
      { className: label, probability: 0.7 },
      ...diseaseLabels
        .filter((candidate) => candidate !== label)
        .map((className) => ({ className, probability: 0.1 })),
    ];
    const client = createAiInferenceClient(configuration, async () => jsonResponse(envelope(data)));
    assert.equal((await client.predict(image)).predictedClass, label);
  }
});

test('validation-based threshold and below-threshold uncertainty remain explicit', async () => {
  for (const [threshold, status, reason] of [
    [0.8, 'LOW_CONFIDENCE', 'BELOW_VALIDATION_THRESHOLD'],
    [0.7, 'CONFIDENT', null],
  ] as const) {
    const data: InferencePrediction = {
      ...prediction(),
      confidenceThreshold: threshold,
      predictionStatus: status,
      uncertaintyReason: reason,
    };
    const client = createAiInferenceClient(configuration, async () => jsonResponse(envelope(data)));
    assert.deepEqual(await client.predict(image), data);
  }
});

test('invalid model response fields cannot reach persistence', async (context) => {
  const mutations: Record<string, unknown>[] = [
    { predictedClass: 'common_rust' },
    { predictedClass: 'unrecognized-disease' },
    { confidence: '0.7' },
    { confidence: -0.1 },
    { confidence: 1.01 },
    { confidence: null },
    { confidence: 0.69 },
    { modelVersion: 'unapproved-model' },
    { modelVersion: 'm'.repeat(81) },
    { preprocessingVersion: 'unapproved-preprocessing' },
    { preprocessingVersion: 'p'.repeat(121) },
    { inferenceDurationMs: -1 },
    { inferenceDurationMs: 20001 },
    { inferenceDurationMs: null },
    { predictionStatus: 'CONFIDENT' },
    { confidenceThreshold: 0 },
    { confidenceThreshold: 1 },
    { confidenceThreshold: 0.8 },
    { uncertaintyReason: null },
    { uncertaintyReason: 'UNKNOWN' },
    { internalPath: '/private/model.pt' },
    { topProbabilities: prediction().topProbabilities.slice(0, 3) },
    {
      topProbabilities: [
        { className: 'Healthy', probability: 0.7 },
        { className: 'Common_Rust', probability: 0.2 },
        { className: 'Common_Rust', probability: 0.07 },
        { className: 'Northern_Corn_Leaf_Blight', probability: 0.03 },
      ],
    },
    {
      topProbabilities: [
        { className: 'Healthy', probability: 0.7 },
        { className: 'Common_Rust', probability: 0.2 },
        { className: 'Gray_Leaf_Spot', probability: 0.09 },
        { className: 'Northern_Corn_Leaf_Blight', probability: 0.03 },
      ],
    },
    {
      topProbabilities: [
        { className: 'Healthy', probability: 0.7 },
        { className: 'Gray_Leaf_Spot', probability: 0.07 },
        { className: 'Common_Rust', probability: 0.2 },
        { className: 'Northern_Corn_Leaf_Blight', probability: 0.03 },
      ],
    },
    {
      predictedClass: 'Healthy',
      confidence: 0.25,
      topProbabilities: [
        { className: 'Healthy', probability: 0.25 },
        { className: 'Common_Rust', probability: 0.25 },
        { className: 'Gray_Leaf_Spot', probability: 0.25 },
        { className: 'Northern_Corn_Leaf_Blight', probability: 0.25 },
      ],
    },
  ];
  for (const [index, mutation] of mutations.entries()) {
    await context.test(`reject incompatible output ${index + 1}`, async () => {
      const client = createAiInferenceClient(configuration, async () =>
        jsonResponse(envelope({ ...prediction(), ...mutation })),
      );
      await assert.rejects(client.predict(image), hasCode('INFERENCE_INVALID_RESPONSE'));
    });
  }
});

test('wire envelopes and content-type are validated rather than unwrapped repeatedly', async () => {
  for (const response of [
    jsonResponse(prediction()),
    jsonResponse({ ...envelope(), success: false }),
    jsonResponse({ ...envelope(), internalConfig: '/private/model.pt' }),
    jsonResponse({ ...envelope(), meta: { requestId: 'invalid-correlation' } }),
    new Response('not-json', { headers: { 'Content-Type': 'application/json' } }),
    new Response('private-provider-message', { headers: { 'Content-Type': 'text/html' } }),
    new Response(new Uint8Array([0xff, 0xfe]), {
      headers: { 'Content-Type': 'application/json' },
    }),
    jsonResponse(envelope(), 201),
  ]) {
    const client = createAiInferenceClient(configuration, async () => response);
    await assert.rejects(client.predict(image), hasCode('INFERENCE_INVALID_RESPONSE'));
  }
});

test('provider failure details and authentication failures map to safe public errors', async () => {
  const cases: [number, string, ErrorCode][] = [
    [422, 'IMAGE_INVALID', 'INVALID_IMAGE'],
    [422, 'IMAGE_DIMENSIONS', 'INVALID_IMAGE'],
    [415, 'IMAGE_UNSUPPORTED', 'INVALID_IMAGE'],
    [413, 'REQUEST_TOO_LARGE', 'INVALID_IMAGE'],
    [422, 'VALIDATION_ERROR', 'INFERENCE_FAILED'],
    [500, 'PREPROCESSING_FAILED', 'INFERENCE_FAILED'],
    [500, 'INFERENCE_FAILED', 'INFERENCE_FAILED'],
    [503, 'MODEL_UNAVAILABLE', 'INFERENCE_UNAVAILABLE'],
    [503, 'INFERENCE_BUSY', 'INFERENCE_UNAVAILABLE'],
    [429, 'RATE_LIMITED', 'INFERENCE_UNAVAILABLE'],
    [401, 'AUTHENTICATION_ERROR', 'INFERENCE_UNAVAILABLE'],
    [403, 'AUTHORIZATION_ERROR', 'INFERENCE_UNAVAILABLE'],
    [408, 'REQUEST_TIMEOUT', 'INFERENCE_TIMEOUT'],
  ];
  for (const [status, code, mapped] of cases) {
    const client = createAiInferenceClient(configuration, async () =>
      jsonResponse(serviceError(code), status),
    );
    await assert.rejects(client.predict(image), hasCode(mapped));
  }
  const unreachable = createAiInferenceClient(configuration, async () => {
    throw new Error(`private-provider-message ${configuration.AI_SERVICE_TOKEN}`);
  });
  await assert.rejects(unreachable.predict(image), hasCode('INFERENCE_UNAVAILABLE'));
});

test('redirects never trigger a secondary fetch or forward the service credential', async () => {
  let requests = 0;
  const client = createAiInferenceClient(configuration, async () => {
    requests++;
    return new Response(null, { status: 307, headers: { Location: 'https://arbitrary.example' } });
  });
  await assert.rejects(client.predict(image), hasCode('INFERENCE_INVALID_RESPONSE'));
  assert.equal(requests, 1);
});

test('bounded response reading rejects oversized or malformed declared lengths and streams', async () => {
  for (const length of ['65537', '-1', 'invalid', '999999999999999999999999']) {
    const response = jsonResponse(envelope());
    response.headers.set('Content-Length', length);
    const client = createAiInferenceClient(configuration, async () => response);
    await assert.rejects(client.predict(image), hasCode('INFERENCE_INVALID_RESPONSE'));
  }
  for (const declaredLength of [null, '1']) {
    let canceled = false;
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(65537));
      },
      cancel() {
        canceled = true;
      },
    });
    const response = new Response(stream, { headers: { 'Content-Type': 'application/json' } });
    if (declaredLength) response.headers.set('Content-Length', declaredLength);
    const client = createAiInferenceClient(configuration, async () => response);
    await assert.rejects(client.predict(image), hasCode('INFERENCE_INVALID_RESPONSE'));
    assert.equal(canceled, true);
  }
});

test('deadline covers unavailable transport and stalled streamed response bodies', async () => {
  let signal: AbortSignal | null | undefined;
  const unavailable = createAiInferenceClient(configuration, async (_input, options) => {
    signal = options?.signal;
    return new Promise<Response>(() => {});
  });
  await assert.rejects(unavailable.predict(image), hasCode('INFERENCE_TIMEOUT'));
  assert.equal(signal?.aborted, true);
  let canceled = false;
  const streaming = createAiInferenceClient(
    configuration,
    async () =>
      new Response(
        new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(new TextEncoder().encode('{'));
          },
          cancel() {
            canceled = true;
          },
        }),
        { headers: { 'Content-Type': 'application/json' } },
      ),
  );
  await assert.rejects(streaming.predict(image), hasCode('INFERENCE_TIMEOUT'));
  assert.equal(canceled, true);
});

test('real native fetch preserves bytes and refuses redirects from a local HTTP service', async () => {
  const received: Buffer[] = [];
  let redirectDestinationRequests = 0;
  let redirect = false;
  const server = createServer(async (request, response) => {
    if (request.url === '/must-not-fetch') {
      redirectDestinationRequests++;
      response.end();
      return;
    }
    assert.equal(request.url, '/api/v1/predict?top_k=4');
    assert.equal(request.headers.authorization, `Bearer ${configuration.AI_SERVICE_TOKEN}`);
    const chunks: Buffer[] = [];
    for await (const chunk of request) chunks.push(Buffer.from(chunk));
    received.push(Buffer.concat(chunks));
    if (redirect) {
      response.writeHead(307, { Location: '/must-not-fetch' });
      response.end();
      return;
    }
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify(envelope()));
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address() as AddressInfo;
    const client = createAiInferenceClient({
      ...configuration,
      AI_SERVICE_URL: `http://127.0.0.1:${address.port}`,
    });
    assert.deepEqual(await client.predict(image), prediction());
    redirect = true;
    await assert.rejects(client.predict(image), hasCode('INFERENCE_INVALID_RESPONSE'));
    assert.deepEqual(received, [image.bytes, image.bytes]);
    assert.equal(redirectDestinationRequests, 0);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
});
