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

const internalServiceUrl = z
  .string()
  .max(2048)
  .default('')
  .refine((value) => {
    if (value === '') return true;
    try {
      const url = new URL(value);
      return (
        ['http:', 'https:'].includes(url.protocol) &&
        url.username === '' &&
        url.password === '' &&
        url.search === '' &&
        url.hash === '' &&
        (value === url.origin || value === `${url.origin}/`)
      );
    } catch {
      return false;
    }
  }, 'Must be a configured HTTP(S) origin without credentials, path, query or fragment.')
  .transform((value) => (value ? new URL(value).origin : ''));

const artifactVersion = z
  .string()
  .max(120)
  .regex(/^(?:[A-Za-z0-9][A-Za-z0-9._-]*)?$/);

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
    SCAN_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(100).default(10),
    CLOUDINARY_CLOUD_NAME: z
      .string()
      .regex(/^[a-zA-Z0-9_-]*$/)
      .max(100)
      .default(''),
    CLOUDINARY_API_KEY: z
      .string()
      .regex(/^[0-9]*$/)
      .max(64)
      .default(''),
    CLOUDINARY_API_SECRET: z.string().max(256).default(''),
    AI_SERVICE_URL: internalServiceUrl,
    AI_SERVICE_TOKEN: z.union([z.literal(''), signingSecret.max(256)]).default(''),
    AI_SERVICE_TIMEOUT_MS: z.coerce.number().int().min(1000).max(20000).default(10000),
    AI_MODEL_VERSION: artifactVersion.max(80).default(''),
    AI_PREPROCESSING_VERSION: artifactVersion.default(''),
    JWT_SECRET: signingSecret,
    JWT_REFRESH_SECRET: signingSecret,
    JWT_ISSUER: z.string().min(1).max(160).default('maizedoctor'),
    JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().min(60).max(900).default(900),
    JWT_REFRESH_TTL_SECONDS: z.coerce.number().int().min(3600).max(2592000).default(604800),
  })
  .refine(
    (value) => {
      const credentials = [
        value.CLOUDINARY_CLOUD_NAME,
        value.CLOUDINARY_API_KEY,
        value.CLOUDINARY_API_SECRET,
      ];
      return (
        credentials.every((key) => key === '') ||
        credentials.every((key) => key.trim().length > 0 && key === key.trim())
      );
    },
    {
      path: ['CLOUDINARY_CLOUD_NAME'],
      message:
        'Supply all three Cloudinary credentials together, or leave all blank to disable uploads.',
    },
  )
  .refine((value) => value.JWT_SECRET !== value.JWT_REFRESH_SECRET, {
    path: ['JWT_REFRESH_SECRET'],
    message: 'Access and refresh signing keys must be different.',
  })
  .refine(
    (value) =>
      value.AI_SERVICE_URL === ''
        ? value.AI_SERVICE_TOKEN === '' &&
          value.AI_MODEL_VERSION === '' &&
          value.AI_PREPROCESSING_VERSION === ''
        : value.AI_SERVICE_TOKEN !== '' &&
          value.AI_MODEL_VERSION !== '' &&
          value.AI_PREPROCESSING_VERSION !== '',
    {
      path: ['AI_SERVICE_URL'],
      message:
        'Supply the AI service origin, token and both expected artifact versions together, or leave all blank to disable inference.',
    },
  );

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
