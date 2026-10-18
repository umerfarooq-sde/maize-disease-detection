import { config } from 'dotenv';
import { isIP } from 'node:net';
import { z } from 'zod';
import { databaseConnectionUrl, hasVerifiedDatabaseTransport } from '../database/connection-url.js';
import { withSecretFile } from './secrets.js';

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

function trustedProxyRange(value: string): boolean {
  const [address, prefix] = value.trim().split('/');
  if (!address || isIP(address) !== 4 || !prefix || !/^\d{1,2}$/.test(prefix)) return false;
  const bits = Number(prefix);
  const octets = address.split('.').map(Number);
  return (
    bits >= 16 &&
    bits <= 32 &&
    (octets[0] === 10 ||
      (octets[0] === 172 && (octets[1] ?? 0) >= 16 && (octets[1] ?? 0) <= 31) ||
      (octets[0] === 192 && octets[1] === 168) ||
      (octets[0] === 127 && bits === 32))
  );
}

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
    REDIS_URL: z
      .string()
      .default('')
      .refine((value) => {
        if (!value) return true;
        try {
          const url = new URL(value);
          return (
            ['redis:', 'rediss:'].includes(url.protocol) &&
            !!url.hostname &&
            !url.hash &&
            !url.search
          );
        } catch {
          return false;
        }
      }, 'Must be a Redis connection URL.'),
    REDIS_NAMESPACE: z
      .string()
      .regex(/^[a-z][a-z0-9_-]{0,39}$/)
      .default('maizedoctor'),
    TRUST_PROXY: z
      .string()
      .max(500)
      .default('')
      .refine(
        (value) => value === '' || value.split(',').every(trustedProxyRange),
        'Use explicit trusted IPv4 CIDRs, never a hop count or wildcard.',
      ),
    OPERATIONS_TOKEN: z.union([z.literal(''), signingSecret.max(256)]).default(''),
    AUTH_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(1000).default(10),
    SCAN_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(100).default(10),
    KNOWLEDGE_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(1000).default(20),
    KNOWLEDGE_INDEX_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120000).default(120000),
    GENERATION_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(60).default(5),
    GENERATION_TIMEOUT_MS: z.coerce.number().int().min(1000).max(60000).default(30000),
    CALCULATOR_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(1000).default(30),
    ANALYTICS_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(1000).default(30),
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
    (value) =>
      value.NODE_ENV !== 'production' ||
      value.CORS_ORIGINS.every((origin) => origin.startsWith('https://')),
    { path: ['CORS_ORIGINS'], message: 'Production browser origins require HTTPS.' },
  )
  .refine(
    (value) => {
      if (value.NODE_ENV !== 'production') return true;
      const url = databaseConnectionUrl(value.DATABASE_URL);
      return hasVerifiedDatabaseTransport(url);
    },
    {
      path: ['DATABASE_URL'],
      message: 'Production remote PostgreSQL requires verified TLS (sslmode=verify-full).',
    },
  )
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
  if (!process.env['MAIZEDOCTOR_SECRETS_FILE']) config({ quiet: true });
  const environment = parseEnvironment(withSecretFile(process.env));
  if (
    environment.NODE_ENV === 'production' &&
    (!environment.REDIS_URL || !environment.OPERATIONS_TOKEN)
  ) {
    throw new Error('Production requires REDIS_URL and an independent OPERATIONS_TOKEN.');
  }
  if (
    environment.OPERATIONS_TOKEN &&
    [environment.JWT_SECRET, environment.JWT_REFRESH_SECRET, environment.AI_SERVICE_TOKEN].includes(
      environment.OPERATIONS_TOKEN,
    )
  ) {
    throw new Error('OPERATIONS_TOKEN must be independent from signing and AI credentials.');
  }
  if (environment.NODE_ENV === 'production') {
    const redis = new URL(environment.REDIS_URL);
    if (
      !redis.password ||
      (redis.protocol !== 'rediss:' && !(redis.protocol === 'redis:' && redis.hostname === 'redis'))
    ) {
      throw new Error(
        'Production Redis requires authentication and private reference networking or verified TLS.',
      );
    }
  }
  const [major, minor] = process.versions.node.split('.').map(Number);
  if (environment.NODE_ENV === 'production' && (major !== 24 || (minor ?? 0) < 22)) {
    throw new Error('Production requires Node.js 24.22.0 or a later maintained 24.x release.');
  }
  return environment;
}
