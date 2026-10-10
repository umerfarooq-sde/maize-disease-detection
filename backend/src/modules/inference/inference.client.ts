import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import type { ValidatedImage } from '../scans/scan.types.js';
import { type AiInferenceClient, predictionSchema } from './inference.types.js';

const responseBytesLimit = 64 * 1024;
const metadataSchema = z.strictObject({ requestId: z.uuid() });
const successSchema = z.strictObject({
  success: z.literal(true),
  data: predictionSchema,
  meta: metadataSchema,
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
  meta: metadataSchema,
});

type AiEnvironment = Pick<
  Environment,
  | 'AI_SERVICE_URL'
  | 'AI_SERVICE_TOKEN'
  | 'AI_SERVICE_TIMEOUT_MS'
  | 'AI_MODEL_VERSION'
  | 'AI_PREPROCESSING_VERSION'
>;

function mappedServiceError(status: number, code: string): AppError {
  if (
    (status === 422 && ['IMAGE_INVALID', 'IMAGE_DIMENSIONS'].includes(code)) ||
    (status === 415 && code === 'IMAGE_UNSUPPORTED') ||
    (status === 413 && code === 'REQUEST_TOO_LARGE')
  )
    return new AppError('INVALID_IMAGE');
  if (status === 408 && code === 'REQUEST_TIMEOUT') return new AppError('INFERENCE_TIMEOUT');
  if (
    [429, 503].includes(status) ||
    (status === 401 && code === 'AUTHENTICATION_ERROR') ||
    (status === 403 && code === 'AUTHORIZATION_ERROR')
  )
    return new AppError('INFERENCE_UNAVAILABLE');
  return new AppError('INFERENCE_FAILED');
}

export function createAiInferenceClient(
  environment: AiEnvironment,
  transport: typeof fetch = fetch,
): AiInferenceClient {
  // The validated, operator-controlled origin is the only network destination.
  // No scan identifier, filename, user URL or Cloudinary URL influences it.
  const endpoint = environment.AI_SERVICE_URL
    ? new URL('/api/v1/predict?top_k=4', environment.AI_SERVICE_URL)
    : null;
  return {
    enabled: endpoint !== null,
    async predict(image: ValidatedImage) {
      if (!endpoint) throw new AppError('INFERENCE_UNAVAILABLE');
      const controller = new AbortController();
      let rejectDeadline: ((error: AppError) => void) | undefined;
      const deadline = new Promise<never>((_resolve, reject) => {
        rejectDeadline = reject;
      });
      const timer = setTimeout(() => {
        controller.abort();
        rejectDeadline?.(new AppError('INFERENCE_TIMEOUT'));
      }, environment.AI_SERVICE_TIMEOUT_MS);
      let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
      try {
        const response = await Promise.race([
          transport(endpoint, {
            method: 'POST',
            redirect: 'manual',
            signal: controller.signal,
            headers: {
              Authorization: `Bearer ${environment.AI_SERVICE_TOKEN}`,
              'Content-Type': image.mimeType,
              'Content-Length': String(image.bytes.length),
              Accept: 'application/json',
              'Accept-Encoding': 'identity',
            },
            body: new Uint8Array(image.bytes),
          }),
          deadline,
        ]);
        if (response.status >= 300 && response.status < 400)
          throw new AppError('INFERENCE_INVALID_RESPONSE');
        const contentType = response.headers.get('content-type')?.split(';')[0]?.trim();
        const declaredLength = response.headers.get('content-length');
        if (
          contentType?.toLowerCase() !== 'application/json' ||
          (declaredLength !== null &&
            (!/^[0-9]{1,10}$/.test(declaredLength) ||
              Number(declaredLength) > responseBytesLimit)) ||
          !response.body
        )
          throw new AppError('INFERENCE_INVALID_RESPONSE');
        reader = response.body.getReader();
        const chunks: Uint8Array[] = [];
        let bytesRead = 0;
        while (true) {
          const chunk = await Promise.race([reader.read(), deadline]);
          if (chunk.done) break;
          bytesRead += chunk.value.byteLength;
          if (bytesRead > responseBytesLimit) throw new AppError('INFERENCE_INVALID_RESPONSE');
          chunks.push(chunk.value);
        }
        let parsed: unknown;
        try {
          parsed = JSON.parse(
            new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)),
          );
        } catch {
          throw new AppError('INFERENCE_INVALID_RESPONSE');
        }
        if (response.status !== 200) {
          const error = errorSchema.safeParse(parsed);
          if (!error.success) throw new AppError('INFERENCE_INVALID_RESPONSE');
          throw mappedServiceError(response.status, error.data.error.code);
        }
        const result = successSchema.safeParse(parsed);
        if (
          !result.success ||
          result.data.data.modelVersion !== environment.AI_MODEL_VERSION ||
          result.data.data.preprocessingVersion !== environment.AI_PREPROCESSING_VERSION
        )
          throw new AppError('INFERENCE_INVALID_RESPONSE');
        return result.data.data;
      } catch (error: unknown) {
        if (controller.signal.aborted) throw new AppError('INFERENCE_TIMEOUT');
        if (error instanceof AppError) throw error;
        // Fetch/stream failures can contain internal origins, token headers and codec details.
        // Never attach their cause or response data to the public/loggable application error.
        throw new AppError('INFERENCE_UNAVAILABLE');
      } finally {
        clearTimeout(timer);
        if (reader) {
          void reader.cancel().catch(() => {});
          reader.releaseLock();
        }
        controller.abort();
      }
    },
  };
}
