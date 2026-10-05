import { type Logger, pino } from 'pino';
import type { Environment } from './environment.js';

export function createLogger(environment: Pick<Environment, 'LOG_LEVEL'>): Logger {
  return pino({
    level: environment.LOG_LEVEL,
    base: { service: 'maizedoctor-backend' },
    // Defense in depth; request logging also omits headers, bodies and query strings.
    redact: {
      paths: [
        'password',
        'token',
        'authorization',
        'databaseUrl',
        'req.headers.authorization',
        'req.headers.cookie',
      ],
      censor: '[REDACTED]',
    },
  });
}
