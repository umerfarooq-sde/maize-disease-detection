import { config } from 'dotenv';
import { z } from 'zod';
import { databaseConnectionUrl } from '../database/connection-url.js';

const environmentSchema = z.object({
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
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  SHUTDOWN_TIMEOUT_MS: z.coerce.number().int().min(1000).max(60000).default(10000),
  RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(10000).default(120),
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
