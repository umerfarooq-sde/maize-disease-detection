import { readFileSync, statSync } from 'node:fs';

const secretKeys = new Set([
  'DATABASE_URL',
  'DIRECT_DATABASE_URL',
  'JWT_SECRET',
  'JWT_REFRESH_SECRET',
  'AI_SERVICE_TOKEN',
  'CLOUDINARY_API_KEY',
  'CLOUDINARY_API_SECRET',
  'REDIS_URL',
  'OPERATIONS_TOKEN',
]);

/** Runtime-mounted JSON only; values and dependency messages must never be logged. */
export function withSecretFile(input: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  const path = input['MAIZEDOCTOR_SECRETS_FILE'];
  if (!path) return input;
  try {
    if (statSync(path).size > 32768) throw new Error();
    const values: unknown = JSON.parse(readFileSync(path, 'utf8'));
    if (!values || typeof values !== 'object' || Array.isArray(values)) throw new Error();
    const result = { ...input };
    for (const [key, value] of Object.entries(values)) {
      if (!secretKeys.has(key) || typeof value !== 'string' || !value) throw new Error();
      if (input[key] && input[key] !== value) throw new Error();
      result[key] = value;
    }
    return result;
  } catch {
    throw new Error(
      'Invalid runtime secret file; check allowed keys, permissions and conflicting environment values.',
    );
  }
}
