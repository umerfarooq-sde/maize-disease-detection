import assert from 'node:assert/strict';
import { Writable } from 'node:stream';
import { test } from 'node:test';
import { createLogger } from '../../src/config/logger.js';

test('configured logger starts and redacts auth credentials and refresh response headers', () => {
  let output = '';
  const destination = new Writable({
    write(chunk: Buffer, _encoding, callback) {
      output += chunk.toString();
      callback();
    },
  });
  const logger = createLogger({ LOG_LEVEL: 'info' }, destination);
  const sensitive = 'synthetic-secret-not-for-output';
  logger.info(
    {
      password: sensitive,
      passwordHash: sensitive,
      accessToken: sensitive,
      refreshToken: sensitive,
      refreshTokenHash: sensitive,
      JWT_SECRET: sensitive,
      JWT_REFRESH_SECRET: sensitive,
      req: { headers: { authorization: sensitive, cookie: sensitive } },
      res: { headers: { 'set-cookie': sensitive } },
    },
    'Redaction check',
  );
  assert.ok(output.includes('Redaction check'));
  assert.ok(output.includes('[REDACTED]'));
  assert.ok(!output.includes(sensitive));
});
