import { type DestinationStream, type Logger, pino } from 'pino';
import type { Environment } from './environment.js';

export function createLogger(
  environment: Pick<Environment, 'LOG_LEVEL'>,
  destination?: DestinationStream,
): Logger {
  return pino(
    {
      level: environment.LOG_LEVEL,
      base: { service: 'maizedoctor-backend' },
      // Defense in depth; request logging also omits headers, bodies and query strings.
      redact: {
        paths: [
          'password',
          'passwordHash',
          'accessToken',
          'refreshToken',
          'refreshTokenHash',
          'JWT_SECRET',
          'JWT_REFRESH_SECRET',
          'token',
          'authorization',
          'databaseUrl',
          'req.headers.authorization',
          'req.headers.cookie',
          'res.headers["set-cookie"]',
        ],
        censor: '[REDACTED]',
      },
    },
    destination,
  );
}
