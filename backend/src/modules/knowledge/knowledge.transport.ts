import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';

const responseBytesLimit = 128 * 1024;
const responseMeta = z.strictObject({ requestId: z.uuid() });
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
  meta: responseMeta,
});

export type KnowledgeEnvironment = Pick<
  Environment,
  'AI_SERVICE_URL' | 'AI_SERVICE_TOKEN' | 'AI_SERVICE_TIMEOUT_MS'
>;

export async function requestKnowledge<T>(
  environment: KnowledgeEnvironment,
  path: 'retrieve' | 'knowledge/prepare' | 'knowledge/index' | 'knowledge/check',
  input: unknown,
  schema: z.ZodType<T>,
  timeoutMs = environment.AI_SERVICE_TIMEOUT_MS,
  transport: typeof fetch = fetch,
): Promise<T> {
  const endpoint = environment.AI_SERVICE_URL
    ? new URL(`/api/v1/${path}`, environment.AI_SERVICE_URL)
    : null;
  const management = path !== 'retrieve';
  if (!endpoint) throw new AppError('KNOWLEDGE_UNAVAILABLE');
  const controller = new AbortController();
  let rejectDeadline: ((error: AppError) => void) | undefined;
  const deadline = new Promise<never>((_resolve, reject) => {
    rejectDeadline = reject;
  });
  const timer = setTimeout(() => {
    controller.abort();
    rejectDeadline?.(new AppError('KNOWLEDGE_TIMEOUT'));
  }, timeoutMs);
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  try {
    const body = JSON.stringify(input);
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
          'Content-Length': String(Buffer.byteLength(body, 'utf8')),
          Accept: 'application/json',
          'Accept-Encoding': 'identity',
        },
        body,
      }),
      deadline,
    ]);
    if (response.status >= 300 && response.status < 400)
      throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
    const contentType = response.headers.get('content-type')?.split(';')[0]?.trim().toLowerCase();
    const declaredLength = response.headers.get('content-length');
    const encoding = response.headers.get('content-encoding');
    if (
      contentType !== 'application/json' ||
      !response.body ||
      (encoding !== null && encoding.toLowerCase() !== 'identity') ||
      (declaredLength !== null &&
        (!/^[0-9]{1,10}$/.test(declaredLength) || Number(declaredLength) > responseBytesLimit))
    )
      throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
    reader = response.body.getReader();
    let bytesRead = 0;
    const chunks: Uint8Array[] = [];
    while (true) {
      const chunk = await Promise.race([reader.read(), deadline]);
      if (chunk.done) break;
      bytesRead += chunk.value.byteLength;
      if (bytesRead > responseBytesLimit) throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
      chunks.push(chunk.value);
    }
    if (declaredLength !== null && Number(declaredLength) !== bytesRead)
      throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
    let parsed: unknown;
    try {
      parsed = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)));
    } catch {
      throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
    }
    if (response.status !== 200) {
      const failure = errorSchema.safeParse(parsed);
      if (!failure.success) throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
      if (management && response.status === 409) throw new AppError('CONFLICT');
      if (management && response.status === 422) throw new AppError('VALIDATION_ERROR');
      if (management && response.status === 413) throw new AppError('PAYLOAD_TOO_LARGE');
      throw new AppError(
        [408, 504].includes(response.status) ? 'KNOWLEDGE_TIMEOUT' : 'KNOWLEDGE_UNAVAILABLE',
      );
    }
    const result = z
      .strictObject({ success: z.literal(true), data: schema, meta: responseMeta })
      .safeParse(parsed);
    if (!result.success) throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
    return result.data.data;
  } catch (error: unknown) {
    if (controller.signal.aborted) throw new AppError('KNOWLEDGE_TIMEOUT');
    if (error instanceof AppError) throw error;
    // Provider text, network causes and origins are not public/loggable data.
    throw new AppError('KNOWLEDGE_UNAVAILABLE');
  } finally {
    clearTimeout(timer);
    if (reader) {
      void reader.cancel().catch(() => {});
      reader.releaseLock();
    }
    controller.abort();
  }
}
