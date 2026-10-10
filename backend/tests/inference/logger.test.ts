import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { test } from 'node:test';
import { createLogger } from '../../src/config/logger.js';

test('server logger redacts the internal AI credential and preserves safe diagnostic codes', () => {
  const token = randomBytes(32).toString('base64url');
  let logs = '';
  const logger = createLogger(
    { LOG_LEVEL: 'info' },
    {
      write(message: string) {
        logs += message;
      },
    },
  );
  logger.error(
    {
      code: 'INFERENCE_UNAVAILABLE',
      AI_SERVICE_TOKEN: token,
      authorization: `Bearer ${token}`,
      req: { headers: { authorization: `Bearer ${token}`, cookie: `service=${token}` } },
    },
    'Internal analysis connection failed',
  );
  assert.ok(!logs.includes(token));
  assert.ok(logs.includes('INFERENCE_UNAVAILABLE'));
  const entry = JSON.parse(logs) as {
    AI_SERVICE_TOKEN: string;
    authorization: string;
    req: { headers: { authorization: string; cookie: string } };
  };
  assert.equal(entry.AI_SERVICE_TOKEN, '[REDACTED]');
  assert.equal(entry.authorization, '[REDACTED]');
  assert.equal(entry.req.headers.authorization, '[REDACTED]');
  assert.equal(entry.req.headers.cookie, '[REDACTED]');
});
