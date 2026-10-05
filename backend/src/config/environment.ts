import { config } from 'dotenv';
import { z } from 'zod';
import { databaseConnectionUrl } from '../database/connection-url.js';

const signingSecret = z
  .string()
  .regex(/^[A-Za-z0-9_-]{43,}$/, 'Must be a base64url-encoded random key of at least 32 bytes.')
  .refine((value) => {
    const key = Buffer.from(value, 'base64url');
    return key.length >= 32 && key.toString('base64url') === value;
  }, 'Must be canonical base64url with at least 32 decoded bytes.');

const environmentSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    HOST: z
      .string()
      .min(1)
      .max(253)
      .regex(/^[a-zA-Z0-9.:-]+$/)
      .default('127.0.0.1'),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    DATABASE_URL: z
      .string()
      .min(1)
      .refine((value) => {
        try {
          databaseConnectionUrl(value);
          return true;
        } catch {
          return false;
        }
      }, 'Must be a PostgreSQL connection URL with a host and database.'),
    CORS_ORIGINS: z
      .string()
      .default('')
      .transform((value) =>
        value
          .split(',')
          .map((origin) => origin.trim())
          .filter(Boolean),
      )
      .refine(
        (origins) =>
          origins.every((origin) => {
            try {
              const url = new URL(origin);
              return ['http:', 'https:'].includes(url.protocol) && url.origin === origin;
            } catch {
              return false;
            }
          }),
        'Must contain comma-separated HTTP(S) origins without paths or credentials.',
      ),
    LOG_LEVEL: z
      .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
      .default('info'),
    SHUTDOWN_TIMEOUT_MS: z.coerce.number().int().min(1000).max(60000).default(10000),
    RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(10000).default(120),
    AUTH_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(1000).default(10),
    JWT_SECRET: signingSecret,
    JWT_REFRESH_SECRET: signingSecret,
    JWT_ISSUER: z.string().min(1).max(160).default('maizedoctor'),
    JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().min(60).max(900).default(900),
    JWT_REFRESH_TTL_SECONDS: z.coerce.number().int().min(3600).max(2592000).default(604800),
  })
  .refine((value) => value.JWT_SECRET !== value.JWT_REFRESH_SECRET, {
    path: ['JWT_REFRESH_SECRET'],
    message: 'Access and refresh signing keys must be different.',
  });

export type Environment = z.infer<typeof environmentSchema>;

export function parseEnvironment(input: Record<string, string | undefined>): Environment {
  const result = environmentSchema.safeParse(input);
  if (!result.success) {
    // Never echo supplied values: invalid database URLs can contain credentials.
    throw new Error(
      `Invalid environment configuration: ${result.error.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`).join('; ')}`,
    );
  }
  return result.data;
}

export function loadEnvironment(): Environment {
  config({ quiet: true });
  return parseEnvironment(process.env);
}
