import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createDatabaseClient } from '../../src/database/client.js';
import { createScanRepository } from '../../src/modules/scans/scan.repository.js';

test('PostgreSQL farmer history keeps microsecond/tied ordering and isolates cursor ownership', {
  timeout: 120000,
}, async (context) => {
  const database = createDatabaseClient(undefined, 30000);
  const repository = createScanRepository(database);
  const owners: string[] = [];
  const scans: string[] = [];
  async function farmer() {
    const row = await database.user.create({
      data: {
        email: `phase13-history-${randomUUID()}@example.invalid`,
        passwordHash: '$argon2id$synthetic_fixture_not_for_login',
        role: 'FARMER',
      },
    });
    owners.push(row.id);
    return row.id;
  }
  async function seed(userId: string | null, timestamp: string, id = randomUUID()) {
    scans.push(id);
    // Supply PostgreSQL timestamps directly; JS Date would erase these microseconds.
    await database.$executeRaw`
      INSERT INTO scans (id,user_id,image_url,cloudinary_public_id,image_mime_type,
                         image_bytes,uploaded_at,status,created_at,updated_at)
      VALUES (${id}::uuid,${userId}::uuid,'https://example.invalid/history-fixture.png',
              ${`phase13-history/${id}`},'image/png',128,${timestamp}::timestamptz,
              'PENDING',${timestamp}::timestamptz,${timestamp}::timestamptz)
    `;
    return id;
  }
  try {
    const owner = await farmer();
    const other = await farmer();
    const ids = Array.from({ length: 6 }, () => randomUUID()).sort();
    const descendingTimes = ['000950', '000850', '000750', '000750', '000650', '000550'];
    for (const [index, id] of ids.entries()) {
      await seed(owner, `2020-01-01T00:00:00.${descendingTimes[index]}Z`, id);
    }
    const expected = [ids[0], ids[1], ids[3], ids[2], ids[4], ids[5]];
    const foreign = await seed(other, '2020-01-02T00:00:00.000000Z');
    const anonymous = await seed(null, '2020-01-03T00:00:00.000000Z');
    let firstCursor: string | null = null;
    await context.test(
      'one UUID cursor retains native timestamp precision and stable tie ordering',
      async () => {
        const visited: string[] = [];
        let cursor: string | undefined;
        for (let index = 0; index < 3; index++) {
          const page = await repository.history(owner, 2, cursor);
          assert.ok(page);
          assert.equal(page.items.length, 2);
          visited.push(...page.items.map((row) => row.id));
          if (index === 0) firstCursor = page.nextCursor;
          cursor = page.nextCursor ?? undefined;
          if (index < 2) assert.ok(cursor);
          else assert.equal(page.nextCursor, null);
          // All six values map to the same Date millisecond; DB ordering still differs.
          assert.ok(
            page.items.every((row) => row.createdAt.toISOString() === '2020-01-01T00:00:00.000Z'),
          );
        }
        assert.deepEqual(visited, expected);
        assert.equal(new Set(visited).size, 6);
      },
    );
    await context.test(
      'a newer inserted scan cannot shift the next page of an earlier cursor',
      async () => {
        assert.ok(firstCursor);
        const newest = await seed(owner, '2020-01-04T00:00:00.000000Z');
        const resumed = await repository.history(owner, 2, firstCursor);
        assert.ok(resumed);
        assert.deepEqual(
          resumed.items.map((row) => row.id),
          expected.slice(2, 4),
        );
        assert.equal((await repository.history(owner, 1))?.items[0]?.id, newest);
      },
    );
    await context.test(
      'foreign, anonymous and unknown cursors disclose no farmer rows',
      async () => {
        for (const cursor of [foreign, anonymous, randomUUID()]) {
          assert.equal(await repository.history(owner, 2, cursor), null);
        }
        assert.deepEqual(
          (await repository.history(other, 20))?.items.map((row) => row.id),
          [foreign],
        );
      },
    );
  } finally {
    await database.scan.deleteMany({ where: { id: { in: scans } } });
    await database.user.deleteMany({ where: { id: { in: owners } } });
    await database.$disconnect();
  }
});
