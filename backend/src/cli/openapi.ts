import { readFile, writeFile } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import type { Router } from 'express';
import { pino } from 'pino';
import SwaggerParser from '@apidevtools/swagger-parser';
import { createApp } from '../app.js';
import { parseEnvironment } from '../config/environment.js';
import { generateOpenApi, registeredOperations } from '../contracts/openapi.js';
// Documentation generation requires no developer credentials or live database.
// This inert configuration is never used to start an application listener.
const environment = parseEnvironment({
  NODE_ENV: 'test',
  DATABASE_URL: 'postgresql://localhost/maizedoctor',
  JWT_SECRET: randomBytes(32).toString('base64url'),
  JWT_REFRESH_SECRET: randomBytes(32).toString('base64url'),
});
const app = createApp(environment, pino({ level: 'silent' }), { async checkDatabase() {} });
const router = app.locals.contractRouter as Router;
const spec = generateOpenApi(router);
const text = `${JSON.stringify(spec, null, 2)}\n`;
// No remote refs are resolved. The generated document has local schemas only.
await SwaggerParser.validate(JSON.parse(text), { resolve: { external: false } });
const destination = new URL('../../openapi.json', import.meta.url);
if (process.argv.includes('--check')) {
  if (JSON.stringify(JSON.parse(await readFile(destination, 'utf8'))) !== JSON.stringify(spec))
    throw new Error('OpenAPI drift: run npm run openapi:generate');
} else if (process.argv.includes('--serve')) {
  const server = createServer((request, response) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
    if (request.url !== '/openapi.json') {
      response.writeHead(404).end();
      return;
    }
    response.setHeader('Content-Type', 'application/json');
    response.end(text);
  });
  server.listen(9090, '127.0.0.1', () =>
    console.log('Local-only API document viewer: http://127.0.0.1:9090/openapi.json'),
  );
} else await writeFile(destination, text);
console.log(
  `OpenAPI 3.1 validated: ${registeredOperations(router).length} operations; runtime request schemas and shared response contracts.`,
);
