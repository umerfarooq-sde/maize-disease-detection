import { randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import type { Express } from 'express';
import { pino } from 'pino';
import { parseEnvironment } from '../../src/config/environment.js';

export const testEnvironment = parseEnvironment({
  NODE_ENV: 'test',
  DATABASE_URL: 'postgresql://localhost/maizedoctor',
  LOG_LEVEL: 'silent',
  JWT_SECRET: randomBytes(32).toString('base64url'),
  JWT_REFRESH_SECRET: randomBytes(32).toString('base64url'),
});
export const silentLogger = pino({ level: 'silent' });

export async function withServer(
  app: Express,
  check: (baseUrl: string) => Promise<void>,
): Promise<void> {
  const server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address() as AddressInfo;
  try {
    await check(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
}
