import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import { createDatabaseClient, databaseConnectionUrl } from '../src/database/client.js';
import { createPrivacyRepository } from '../src/modules/privacy/privacy.repository.js';

const runtime = process.env['TEST_PRIVACY_NODE_DATABASE_URL'];
const administrator = process.env['TEST_OPERATIONAL_ADMIN_URL'];
test('dedicated local Node role persists owner-bound requests but cannot approve erasure', {
  skip: !runtime || !administrator,
}, async () => {
  assert.ok(runtime && administrator);
  for (const value of [runtime, administrator]) {
    const url = databaseConnectionUrl(value);
    assert.ok(['localhost', '127.0.0.1', 'postgres'].includes(url.hostname));
    assert.match(url.pathname, /^\/phase25_(?:ci|native_final)$/);
  }
  const db = createDatabaseClient(runtime),
    admin = createDatabaseClient(administrator);
  const userId = randomUUID();
  let requestId: string | undefined;
  try {
    await db.user.create({
      data: {
        id: userId,
        email: `phase25-${userId}@example.invalid`,
        passwordHash: 'synthetic-never-login',
      },
    });
    const repository = createPrivacyRepository(db);
    const first = await repository.request(userId, randomUUID());
    requestId = first.id;
    assert.equal(first.status, 'REQUESTED');
    assert.equal(first.erasureAutomaticallyEnabled, false);
    assert.equal((await repository.request(userId, randomUUID())).id, first.id);
    assert.equal((await repository.read(userId))?.id, first.id);
    assert.equal(await repository.read(randomUUID()), null);
    await assert.rejects(
      db.$executeRaw`UPDATE privacy_requests SET status='REJECTED' WHERE user_id=${userId}::uuid`,
      (error) => /42501|permission denied/.test(JSON.stringify(error)),
    );
  } finally {
    await admin.privacyRequest.deleteMany({ where: { userId } });
    await admin.user.deleteMany({
      where: { id: userId, email: `phase25-${userId}@example.invalid` },
    });
    if (requestId)
      await admin.auditLog.deleteMany({
        where: { entityId: requestId, entityType: 'privacy_request' },
      });
    await Promise.all([db.$disconnect(), admin.$disconnect()]);
  }
});
