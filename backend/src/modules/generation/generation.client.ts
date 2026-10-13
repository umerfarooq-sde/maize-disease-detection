import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import {
  type AskInput,
  assertPredictionPreserved,
  type GenerationClient,
  generationDataSchema,
  type PredictionContext,
} from './generation.types.js';

const responseBytesLimit = 128 * 1024;
const metaSchema = z.strictObject({ requestId: z.uuid() });
const successSchema = z.strictObject({
  success: z.literal(true),
  data: generationDataSchema,
  meta: metaSchema,
});
const errorSchema = z.strictObject({
  success: z.literal(false),
  error: z.strictObject({
    code: z.string().regex(/^[A-Z_]{1,80}$/),
    message: z.string().max(2048),
    issues: z
      .array(
        z.strictObject({
          source: z.enum(['body', 'query', 'path', 'header', 'cookie', 'request']),
          code: z.string().max(160),
        }),
      )
      .max(20),
  }),
  meta: metaSchema,
});
type GenerationEnvironment = Pick<
  Environment,
  'AI_SERVICE_URL' | 'AI_SERVICE_TOKEN' | 'GENERATION_TIMEOUT_MS'
>;

export function createGenerationClient(
  environment: GenerationEnvironment,
  transport: typeof fetch = fetch,
): GenerationClient {
  async function post(
    path: '/api/v1/generate' | '/api/v1/explain',
    body: AskInput | { prediction: PredictionContext },
    expectedPrediction: PredictionContext | null,
  ) {
    if (!environment.AI_SERVICE_URL) throw new AppError('GEN_UNAVAILABLE');
    const endpoint = new URL(path, environment.AI_SERVICE_URL);
    const controller = new AbortController();
    let rejectDeadline: ((error: AppError) => void) | undefined;
    const deadline = new Promise<never>((_resolve, reject) => {
      rejectDeadline = reject;
    });
    const timer = setTimeout(() => {
      controller.abort();
      rejectDeadline?.(new AppError('GEN_TIMEOUT'));
    }, environment.GENERATION_TIMEOUT_MS);
    let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
    try {
      const payload = JSON.stringify(body);
      const response = await Promise.race([
        transport(endpoint, {
          method: 'POST',
          redirect: 'manual',
          signal: controller.signal,
          headers: {
            ...(environment.AI_SERVICE_TOKEN
              ? { Authorization: `Bearer ${environment.AI_SERVICE_TOKEN}` }
              : {}),
            'Content-Type': 'application/json',
            'Content-Length': String(Buffer.byteLength(payload, 'utf8')),
            Accept: 'application/json',
            'Accept-Encoding': 'identity',
          },
          body: payload,
        }),
        deadline,
      ]);
      if (response.status >= 300 && response.status < 400)
        throw new AppError('GEN_INVALID_RESPONSE');
      const type = response.headers.get('content-type')?.split(';')[0]?.trim().toLowerCase();
      const declaredLength = response.headers.get('content-length');
      const encoding = response.headers.get('content-encoding');
      if (
        type !== 'application/json' ||
        !response.body ||
        (encoding !== null && encoding.toLowerCase() !== 'identity') ||
        (declaredLength !== null &&
          (!/^[0-9]{1,10}$/.test(declaredLength) || Number(declaredLength) > responseBytesLimit))
      )
        throw new AppError('GEN_INVALID_RESPONSE');
      reader = response.body.getReader();
      const chunks: Uint8Array[] = [];
      let bytesRead = 0;
      while (true) {
        const chunk = await Promise.race([reader.read(), deadline]);
        if (chunk.done) break;
        if (bytesRead + chunk.value.byteLength > responseBytesLimit)
          throw new AppError('GEN_INVALID_RESPONSE');
        bytesRead += chunk.value.byteLength;
        chunks.push(chunk.value);
      }
      if (declaredLength !== null && Number(declaredLength) !== bytesRead)
        throw new AppError('GEN_INVALID_RESPONSE');
      let parsed: unknown;
      try {
        parsed = JSON.parse(
          new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)),
        );
      } catch {
        throw new AppError('GEN_INVALID_RESPONSE');
      }
      if (response.status !== 200) {
        if (!errorSchema.safeParse(parsed).success) throw new AppError('GEN_INVALID_RESPONSE');
        throw new AppError(
          [408, 504].includes(response.status) ? 'GEN_TIMEOUT' : 'GEN_UNAVAILABLE',
        );
      }
      const result = successSchema.safeParse(parsed);
      if (!result.success) throw new AppError('GEN_INVALID_RESPONSE');
      assertPredictionPreserved(result.data.data, expectedPrediction);
      if (
        'knowledgeType' in body &&
        body.knowledgeType !== undefined &&
        result.data.data.sections.some((section) => section.knowledgeType !== body.knowledgeType)
      )
        throw new AppError('GEN_INVALID_RESPONSE');
      return result.data.data;
    } catch (error: unknown) {
      if (controller.signal.aborted) throw new AppError('GEN_TIMEOUT');
      if (error instanceof AppError) throw error;
      // Do not retain raw SDK/service responses or network error causes.
      throw new AppError('GEN_UNAVAILABLE');
    } finally {
      clearTimeout(timer);
      if (reader) {
        void reader.cancel().catch(() => {});
        reader.releaseLock();
      }
      controller.abort();
    }
  }
  return {
    enabled: environment.AI_SERVICE_URL !== '',
    ask(input) {
      return post('/api/v1/generate', input, null);
    },
    explain(prediction) {
      return post('/api/v1/explain', { prediction }, prediction);
    },
  };
}
