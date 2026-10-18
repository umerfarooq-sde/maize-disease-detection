import assert from 'node:assert/strict';
import test from 'node:test';
import { randomUUID } from 'node:crypto';
import express from 'express';
import { AppError } from '../../src/errors/app-error.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import type { AuthService } from '../../src/modules/auth/auth.service.js';
import { privacyRoutes } from '../../src/modules/privacy/privacy.routes.js';
import { createPrivacyService } from '../../src/modules/privacy/privacy.service.js';
import type { PrivacyProjection } from '../../src/modules/privacy/privacy.types.js';
import { silentLogger, withServer } from './helpers.js';

test('Farmer erasure request is authenticated, owner-bound, idempotent and never enables deletion', async () => {
  const owners: string[] = [];
  const user = randomUUID();
  let record: PrivacyProjection | null = null;
  const service = createPrivacyService({
    async read(id) {
      owners.push(id);
      return record;
    },
    async request(id) {
      owners.push(id);
      record ??= {
        id: randomUUID(),
        status: 'REQUESTED',
        requestedAt: new Date().toISOString(),
        completedAt: null,
        erasureAutomaticallyEnabled: false,
      };
      return record;
    },
  });
  const auth = {
    async authenticate(token: string) {
      if (token !== 'farmer.token.signature' && token !== 'admin.token.signature')
        throw new AppError('AUTHENTICATION_ERROR');
      return {
        userId: user,
        sessionId: randomUUID(),
        role: token.startsWith('farmer') ? 'FARMER' : 'ADMIN',
        user: {
          email: 'synthetic@example.invalid',
          role: 'FARMER',
          createdAt: new Date().toISOString(),
        },
      };
    },
  } as AuthService;
  const app = express();
  app.use(express.json());
  app.use(requestContext(silentLogger));
  app.use(privacyRoutes(auth, service));
  app.use(errorHandler(silentLogger));
  await withServer(app, async (base) => {
    assert.equal((await fetch(base + '/profile/data-deletion')).status, 401);
    assert.equal(
      (
        await fetch(base + '/profile/data-deletion', {
          headers: { Authorization: 'Bearer admin.token.signature' },
        })
      ).status,
      403,
    );
    const headers = {
      Authorization: 'Bearer farmer.token.signature',
      'X-Auth-Request': '1',
      'Content-Type': 'application/json',
    };
    const initial = await fetch(base + '/profile/data-deletion', { headers });
    assert.equal((await initial.json()).data.request, null);
    assert.equal(
      (
        await fetch(base + '/profile/data-deletion', {
          method: 'POST',
          headers: { Authorization: headers.Authorization },
        })
      ).status,
      403,
    );
    const first = await fetch(base + '/profile/data-deletion', {
      method: 'POST',
      headers,
      body: '{}',
    });
    const payload = await first.json();
    assert.equal(first.status, 200);
    assert.equal(first.headers.get('Cache-Control'), 'no-store');
    assert.equal(payload.data.request.erasureAutomaticallyEnabled, false);
    const repeat = await fetch(base + '/profile/data-deletion', {
      method: 'POST',
      headers,
      body: '{}',
    });
    assert.equal((await repeat.json()).data.request.id, payload.data.request.id);
    assert.ok(!JSON.stringify(payload).includes(user));
    assert.equal(
      (await fetch(base + '/profile/data-deletion?userId=' + randomUUID(), { headers })).status,
      400,
    );
  });
  assert.ok(owners.every((id) => id === user));
});
