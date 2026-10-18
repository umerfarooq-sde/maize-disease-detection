import assert from 'node:assert/strict';
import { test } from 'node:test';
import { runScheduledCycle, type WorkerLease } from '../../src/infrastructure/scheduler.js';

test('scheduled worker invokes purposes serially under one owned lease and releases it', async () => {
  const rows: string[] = [];
  const lease: WorkerLease = {
    async acquire(id) {
      rows.push('acquire:' + id);
      return true;
    },
    async renew() {
      return true;
    },
    async release(id) {
      rows.push('release:' + id);
    },
  };
  const result = await runScheduledCycle(
    lease,
    [
      async () => {
        rows.push('scan');
      },
      async () => {
        rows.push('profile');
      },
      async () => {
        rows.push('reference');
      },
    ],
    new AbortController().signal,
  );
  assert.equal(result, 'completed');
  assert.deepEqual(rows.slice(1, -1), ['scan', 'profile', 'reference']);
  assert.equal(rows[0]?.split(':')[1], rows.at(-1)?.split(':')[1]);
});

test('lease loss aborts child work and preserves future work; another replica skips a busy lease', async () => {
  let released = false,
    called = 0;
  const lease: WorkerLease = {
    async acquire() {
      return true;
    },
    async renew() {
      return false;
    },
    async release() {
      released = true;
    },
  };
  await assert.rejects(
    runScheduledCycle(
      lease,
      [
        (signal) =>
          new Promise<void>((_, reject) =>
            signal.addEventListener('abort', () => reject(new Error('interrupted')), {
              once: true,
            }),
          ),
        async () => {
          called++;
        },
      ],
      new AbortController().signal,
      5,
      1000,
    ),
  );
  assert.equal(released, true);
  assert.equal(called, 0);
  lease.acquire = async () => false;
  assert.equal(
    await runScheduledCycle(
      lease,
      [
        async () => {
          called++;
        },
      ],
      new AbortController().signal,
    ),
    'busy',
  );
  assert.equal(called, 0);
});
