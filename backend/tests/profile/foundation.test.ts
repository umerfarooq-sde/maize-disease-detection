import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import express from 'express';
import { AppError } from '../../src/errors/app-error.js';
import type { FarmerProfile } from '../../src/generated/prisma/client.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { accountsRoutes } from '../../src/modules/admin/accounts.routes.js';
import { createAccountsService } from '../../src/modules/admin/accounts.service.js';
import {
  accountRevision,
  auditQuery,
  type FarmerRow,
  farmerQuery,
  safeAuditMetadata,
  statusPatch,
} from '../../src/modules/admin/accounts.types.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { profileRoutes } from '../../src/modules/profile/profile.routes.js';
import { createProfileService } from '../../src/modules/profile/profile.service.js';
import { profilePatch, profileResponse } from '../../src/modules/profile/profile.types.js';
import type { ProfileMediaRepository } from '../../src/modules/profile/profile-media.repository.js';
import { profileMediaRoutes } from '../../src/modules/profile/profile-media.routes.js';
import { createProfileMediaService } from '../../src/modules/profile/profile-media.service.js';
import type { ValidatedImage } from '../../src/modules/scans/scan.types.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { imageFile } from '../scans/helpers.js';

export function profileRow(userId: string = randomUUID()): FarmerProfile {
  return {
    id: randomUUID(),
    userId,
    displayName: 'Fixture farmer',
    phone: null,
    region: null,
    countryCode: null,
    fieldAreaHectares: null,
    avatarUrl: null,
    avatarPublicId: null,
    avatarPendingPublicId: null,
    avatarUploadStartedAt: null,
    avatarCleanupPublicIds: [],
    preferredLanguage: 'en',
    createdAt: new Date('2026-10-15T00:00:00Z'),
    updatedAt: new Date('2026-10-15T00:00:00Z'),
  };
}
export async function authFixture() {
  const state = memoryRepository(),
    auth = createAuthService(testEnvironment, state.repository);
  const password = 'a synthetic testing passphrase';
  await auth.createAdmin({ email: 'admin-profile@example.invalid', password });
  const admin = (await auth.login({ email: 'admin-profile@example.invalid', password }))
    .accessToken;
  const farmers: string[] = [];
  for (const email of ['farmer-one@example.invalid', 'farmer-two@example.invalid']) {
    await auth.register({ email, password });
    farmers.push((await auth.login({ email, password })).accessToken);
  }
  const app = express();
  app.use(requestContext(silentLogger));
  app.use(express.json({ limit: '100kb' }));
  return {
    state,
    auth,
    admin,
    farmers,
    app,
    finish() {
      app.use(errorHandler(silentLogger));
    },
  };
}
export const headers = (token: string) => ({
  Authorization: `Bearer ${token}`,
  'Content-Type': 'application/json',
  'X-Auth-Request': '1',
});

test('profile accepts bounded Unicode metadata and exact decimal hectares, never security fields', () => {
  const base = {
    expectedRevision: null,
    displayName: ' 🌽 Farmer ',
    fieldAreaHectares: '1.2345',
    countryCode: 'pk',
  };
  const result = profilePatch.parse(base);
  assert.equal(result.displayName, '🌽 Farmer');
  assert.equal(result.countryCode, 'PK');
  for (const field of [
    'role',
    'passwordHash',
    'email',
    'userId',
    'id',
    'phone',
    'avatarUrl',
    'avatarPublicId',
  ]) {
    assert.equal(profilePatch.safeParse({ ...base, [field]: 'forbidden' }).success, false, field);
  }
  for (const value of ['', '0', '-1', '1e2', '01', '1.12345', '100000000', 'NaN']) {
    assert.equal(
      profilePatch.safeParse({ ...base, fieldAreaHectares: value }).success,
      false,
      value,
    );
  }
  for (const displayName of ['', ' ', 'x'.repeat(121), 'bad\u0000value'])
    assert.equal(profilePatch.safeParse({ ...base, displayName }).success, false);
  assert.equal(profilePatch.safeParse({ expectedRevision: null, region: 'Region' }).success, false);
  assert.equal(profilePatch.safeParse({ expectedRevision: 'a'.repeat(64) }).success, false);
  assert.equal(
    profilePatch.safeParse({ ...base, region: null, countryCode: null, fieldAreaHectares: null })
      .success,
    true,
  );
});

test('profile projection excludes identifiers, phone and storage journal; revision changes with public content', () => {
  const row = profileRow();
  const result = profileResponse(row).profile;
  assert.ok(result);
  assert.equal(Object.keys(result).length, 7);
  assert.equal(JSON.stringify(result).includes(row.id), false);
  assert.notEqual(
    profileResponse({ ...row, displayName: 'Changed' }).profile?.revision,
    result.revision,
  );
  assert.deepEqual(profileResponse(null), { profile: null });
});

test('profile HTTP derives the owner from FARMER authentication, validates PATCH and handles failures', async () => {
  const f = await authFixture();
  const rows = new Map<string, FarmerProfile>();
  let fail = false;
  f.app.use(
    '/api/v1',
    profileRoutes(
      f.auth,
      createProfileService({
        async read(userId) {
          if (fail) throw new Error('private database details');
          return rows.get(userId) ?? null;
        },
        async patch(userId, input) {
          const current = rows.get(userId) ?? null;
          if ((profileResponse(current).profile?.revision ?? null) !== input.expectedRevision)
            throw new AppError('CONFLICT');
          const next = {
            ...(current ?? profileRow(userId)),
            displayName: input.displayName ?? current?.displayName ?? 'Fixture',
          };
          rows.set(userId, next);
          return next;
        },
      }),
    ),
  );
  f.finish();
  await withServer(f.app, async (base) => {
    const path = `${base}/api/v1/profile`;
    for (const token of ['', 'invalid', f.admin])
      assert.equal(
        (await fetch(path, { headers: headers(token) })).status,
        token === f.admin ? 403 : 401,
      );
    assert.equal((await fetch(path, { headers: headers(f.farmers[0]!) })).status, 200);
    const body = { expectedRevision: null, displayName: 'Saved farmer' };
    const saved = await fetch(path, {
      method: 'PATCH',
      headers: headers(f.farmers[0]!),
      body: JSON.stringify(body),
    });
    assert.equal(saved.status, 200);
    assert.equal(saved.headers.get('cache-control'), 'no-store');
    assert.equal((await saved.json()).data.profile.displayName, 'Saved farmer');
    const other = await fetch(path, { headers: headers(f.farmers[1]!) });
    assert.equal((await other.json()).data.profile, null);
    for (const attack of [
      { ...body, role: 'ADMIN' },
      { ...body, userId: randomUUID() },
      { ...body, fieldAreaHectares: '-1' },
    ]) {
      assert.equal(
        (
          await fetch(path, {
            method: 'PATCH',
            headers: headers(f.farmers[0]!),
            body: JSON.stringify(attack),
          })
        ).status,
        400,
      );
    }
    assert.equal(
      (await fetch(`${path}?userId=${randomUUID()}`, { headers: headers(f.farmers[0]!) })).status,
      400,
    );
    assert.equal(
      (await fetch(`${path}/${randomUUID()}`, { headers: headers(f.farmers[0]!) })).status,
      404,
    );
    assert.equal(
      (
        await fetch(path, {
          method: 'PATCH',
          headers: headers(f.farmers[0]!),
          body: JSON.stringify(body),
        })
      ).status,
      409,
    );
    fail = true;
    const error = await fetch(path, { headers: headers(f.farmers[0]!) });
    assert.equal(error.status, 500);
    assert.equal((await error.text()).includes('private database details'), false);
  });
});

test('Admin filters and status patches are bounded and audit metadata is an allowlist', () => {
  for (const input of [
    { limit: 0 },
    { limit: 51 },
    { cursor: 'bad' },
    { status: 'ADMIN' },
    { email: 'bad' },
    { q: 'arbitrary' },
  ])
    assert.equal(farmerQuery.safeParse(input).success, false);
  for (const input of [
    { from: '2026-10-15' },
    { from: '2026-10-16', to: '2026-10-15' },
    { from: '2025-01-01', to: '2026-10-15' },
    { actorId: 'bad' },
    { action: 'LOGIN' },
  ])
    assert.equal(auditQuery.safeParse(input).success, false);
  assert.equal(
    auditQuery.safeParse({ from: '2026-10-15', to: '2026-10-15', limit: 20 }).success,
    true,
  );
  assert.equal(
    statusPatch.safeParse({ status: 'ACTIVE', expectedRevision: 'a'.repeat(64), role: 'ADMIN' })
      .success,
    false,
  );
  assert.deepEqual(
    safeAuditMetadata({
      passwordHash: 'private',
      token: 'private',
      fields: { name: 'private', secret: 'private' },
      fromStatus: 'ACTIVE',
      revokedSessions: 2,
      version: Infinity,
    }),
    { fromStatus: 'ACTIVE', revokedSessions: 2, fieldsChanged: ['name'] },
  );
});

test('all account/audit endpoints enforce ADMIN before querying and return safe bounded projections', async () => {
  const f = await authFixture();
  let calls = 0;
  const row: FarmerRow = {
    id: randomUUID(),
    email: 'account@example.invalid',
    status: 'ACTIVE',
    createdAt: new Date(),
    updatedAt: new Date(),
    farmerProfile: { displayName: 'Fixture' },
  };
  const service = createAccountsService({
    async farmers() {
      calls++;
      return { items: [row], nextCursor: null };
    },
    async status(id, input) {
      calls++;
      if (id !== row.id) throw new AppError('NOT_FOUND');
      if (input.expectedRevision !== accountRevision(row)) throw new AppError('CONFLICT');
      return { ...row, status: input.status };
    },
    async audits() {
      calls++;
      return {
        items: [
          {
            id: randomUUID(),
            action: 'UPDATE',
            entityType: 'farmer_account',
            entityId: row.id,
            createdAt: new Date(),
            actor: { id: randomUUID(), role: 'ADMIN' },
            changes: { token: 'PRIVATE_NEVER_RETURN', toStatus: 'ACTIVE' },
          },
        ],
        nextCursor: null,
      };
    },
  });
  f.app.use('/api/v1', accountsRoutes(f.auth, service));
  f.finish();
  await withServer(f.app, async (base) => {
    const targets = [
      ['GET', '/admin/farmers'],
      ['GET', '/admin/audit-logs'],
      ['PATCH', `/admin/farmers/${row.id}/status`],
    ] as const;
    for (const [method, path] of targets)
      for (const token of ['', 'invalid', ...f.farmers]) {
        const response = await fetch(`${base}/api/v1${path}`, {
          method,
          headers: headers(token),
          ...(method === 'PATCH' ? { body: '{}' } : {}),
        });
        assert.equal(response.status, f.farmers.includes(token) ? 403 : 401);
      }
    assert.equal(calls, 0);
    const list = await fetch(`${base}/api/v1/admin/farmers`, { headers: headers(f.admin) });
    assert.equal(list.status, 200);
    assert.equal(list.headers.get('cache-control'), 'no-store');
    assert.equal((await list.json()).data.items[0].email, row.email);
    const audits = await fetch(`${base}/api/v1/admin/audit-logs`, { headers: headers(f.admin) });
    const auditText = await audits.text();
    assert.equal(auditText.includes('PRIVATE_NEVER_RETURN'), false);
    for (const query of ['limit=51', 'status=ADMIN', 'cursor=bad', 'limit=1&limit=2'])
      assert.equal(
        (await fetch(`${base}/api/v1/admin/farmers?${query}`, { headers: headers(f.admin) }))
          .status,
        400,
      );
    const changed = await fetch(`${base}/api/v1/admin/farmers/${row.id}/status`, {
      method: 'PATCH',
      headers: headers(f.admin),
      body: JSON.stringify({ status: 'SUSPENDED', expectedRevision: accountRevision(row) }),
    });
    assert.equal(changed.status, 200);
    assert.equal((await changed.json()).data.farmer.status, 'SUSPENDED');
  });
});

function mediaFixture() {
  const row = profileRow(),
    assets = new Set<string>();
  const state = {
    finishFails: false,
    finishAcknowledgementFails: false,
    uploadFails: false,
    destroyFails: false,
    reservedBeforeUpload: false,
  };
  const repository: ProfileMediaRepository = {
    async read() {
      return row;
    },
    async reserve(_user, revision, id) {
      if (row.avatarPendingPublicId) throw new AppError('UPLOAD_IN_PROGRESS');
      if (revision !== profileResponse(row).profile?.revision) throw new AppError('CONFLICT');
      row.avatarPendingPublicId = id;
      row.avatarUploadStartedAt = new Date();
    },
    async finish(_user, id, stored) {
      if (state.finishFails) throw new Error('database unavailable');
      if (row.avatarPendingPublicId !== id) throw new AppError('CONFLICT');
      if (row.avatarPublicId) row.avatarCleanupPublicIds.push(row.avatarPublicId);
      row.avatarPublicId = id;
      row.avatarUrl = stored.url;
      row.avatarPendingPublicId = null;
      row.avatarUploadStartedAt = null;
      if (state.finishAcknowledgementFails) throw new Error('commit acknowledgement lost');
    },
    async remove() {
      if (row.avatarPublicId) row.avatarCleanupPublicIds.push(row.avatarPublicId);
      row.avatarPublicId = null;
      row.avatarUrl = null;
    },
    async candidates() {
      return row.avatarPendingPublicId || row.avatarCleanupPublicIds.length ? [row] : [];
    },
    async retirePending(_user, cutoff, publicId) {
      if (
        row.avatarPendingPublicId &&
        row.avatarUploadStartedAt &&
        (publicId ? row.avatarPendingPublicId === publicId : row.avatarUploadStartedAt < cutoff)
      ) {
        row.avatarCleanupPublicIds.push(row.avatarPendingPublicId);
        row.avatarPendingPublicId = null;
        row.avatarUploadStartedAt = null;
      }
    },
    async cleared(_user, id) {
      row.avatarCleanupPublicIds = row.avatarCleanupPublicIds.filter((item) => item !== id);
      if (row.avatarPendingPublicId === id) {
        row.avatarPendingPublicId = null;
        row.avatarUploadStartedAt = null;
      }
    },
  };
  const service = createProfileMediaService(repository, {
    enabled: true,
    async upload(_image, id) {
      state.reservedBeforeUpload = row.avatarPendingPublicId === id;
      assets.add(id);
      if (state.uploadFails) throw new AppError('UPLOAD_FAILED');
      return {
        publicId: id,
        url: `https://res.cloudinary.com/fixture/image/authenticated/${id}.png`,
        uploadedAt: new Date(),
      };
    },
    async destroy(id) {
      if (state.destroyFails) throw new AppError('UPLOAD_FAILED');
      assets.delete(id);
    },
  });
  const image: ValidatedImage = {
    bytes: Buffer.from('fixture'),
    mimeType: 'image/png',
    width: 24,
    height: 24,
    orientation: 1,
  };
  return {
    service,
    repository,
    row,
    assets,
    state,
    image,
    revision: () => profileResponse(row).profile!.revision,
  };
}

test('profile photo journal reserves before upload, replaces privately and cleans removed assets', async () => {
  const f = mediaFixture();
  await f.service.upload(f.row.userId, f.revision(), f.image);
  assert.equal(f.state.reservedBeforeUpload, true);
  assert.equal(f.assets.size, 1);
  const first = f.row.avatarPublicId;
  await f.service.upload(f.row.userId, f.revision(), f.image);
  assert.notEqual(f.row.avatarPublicId, first);
  assert.equal(f.assets.size, 1);
  assert.equal(f.row.avatarPendingPublicId, null);
  assert.deepEqual(f.row.avatarCleanupPublicIds, []);
  await f.service.remove(f.row.userId, f.revision());
  assert.equal(f.row.avatarUrl, null);
  assert.equal(f.assets.size, 0);
});
test('failed photo commit compensates cloud upload without replacing the old photo', async () => {
  const f = mediaFixture();
  await f.service.upload(f.row.userId, f.revision(), f.image);
  const old = f.row.avatarPublicId;
  f.state.finishFails = true;
  await assert.rejects(f.service.upload(f.row.userId, f.revision(), f.image));
  assert.equal(f.row.avatarPublicId, old);
  assert.equal(f.assets.size, 1);
  assert.equal(f.row.avatarPendingPublicId, null);
});

test('lost photo commit acknowledgement preserves the committed asset instead of compensating it', async () => {
  const f = mediaFixture();
  f.state.finishAcknowledgementFails = true;
  const result = await f.service.upload(f.row.userId, f.revision(), f.image);
  assert.ok(result.profile?.avatarUrl);
  assert.ok(f.row.avatarPublicId);
  assert.ok(f.assets.has(f.row.avatarPublicId));
  assert.equal(f.assets.size, 1);
  assert.equal(f.row.avatarPendingPublicId, null);
});

test('uncertain photo DB outcome retains the asset and recovery intent without unsafe deletion', async () => {
  const f = mediaFixture();
  f.state.finishFails = true;
  f.repository.retirePending = async () => {
    throw new Error('database unavailable');
  };
  await assert.rejects(f.service.upload(f.row.userId, f.revision(), f.image));
  assert.ok(f.row.avatarPendingPublicId);
  assert.equal(f.assets.size, 1);
});
test('failed upload/compensation retains a recoverable intent; stale cleanup never deletes current photo', async () => {
  const f = mediaFixture();
  f.state.uploadFails = true;
  f.state.destroyFails = true;
  await assert.rejects(f.service.upload(f.row.userId, f.revision(), f.image));
  assert.ok(f.row.avatarPendingPublicId);
  assert.equal(f.assets.size, 1);
  await assert.rejects(
    f.service.upload(f.row.userId, f.revision(), f.image),
    (error: unknown) => error instanceof AppError && error.code === 'UPLOAD_IN_PROGRESS',
  );
  f.state.destroyFails = false;
  f.row.avatarUploadStartedAt = new Date(0);
  const result = await f.service.cleanup();
  assert.deepEqual(result, { removed: 1, failed: 0 });
  assert.equal(f.assets.size, 0);
  assert.equal(f.row.avatarPendingPublicId, null);
});
test('old-photo deletion failure remains queued after successful replacement', async () => {
  const f = mediaFixture();
  await f.service.upload(f.row.userId, f.revision(), f.image);
  f.state.destroyFails = true;
  await f.service.upload(f.row.userId, f.revision(), f.image);
  assert.equal(f.row.avatarCleanupPublicIds.length, 1);
  assert.equal(f.assets.size, 2);
  const current = f.row.avatarPublicId;
  f.state.destroyFails = false;
  await f.service.cleanup();
  assert.deepEqual(f.row.avatarCleanupPublicIds, []);
  assert.equal(f.assets.size, 1);
  assert.ok(current && f.assets.has(current));
});
test('photo API admits decoded JPEG/PNG/WebP and rejects malformed media, extra fields and non-farmers', async () => {
  const f = await authFixture(),
    media = mediaFixture();
  let calls = 0;
  f.app.use(
    '/api/v1',
    profileMediaRoutes(f.auth, {
      enabled: true,
      imageLocation: media.service.imageLocation,
      cleanup: media.service.cleanup,
      async upload() {
        calls++;
        return profileResponse(media.row);
      },
      remove: media.service.remove,
    }),
  );
  f.finish();
  await withServer(f.app, async (base) => {
    const path = `${base}/api/v1/profile/avatar`;
    async function send(
      token: string,
      format: 'png' | 'jpeg' | 'webp',
      corrupt = false,
      extra = false,
    ) {
      const image = await imageFile(format),
        form = new FormData();
      form.set('expectedRevision', 'a'.repeat(64));
      form.set(
        'image',
        new Blob([new Uint8Array(corrupt ? Buffer.from('invalid') : image.buffer)], {
          type: image.mimetype,
        }),
        image.originalname,
      );
      if (extra) form.set('userId', randomUUID());
      return fetch(path, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'X-Auth-Request': '1' },
        body: form,
      });
    }
    assert.equal((await send(f.admin, 'png')).status, 403);
    assert.equal((await send('invalid', 'png')).status, 401);
    for (const format of ['png', 'jpeg', 'webp'] as const)
      assert.equal((await send(f.farmers[0]!, format)).status, 200);
    assert.equal(calls, 3);
    assert.equal((await send(f.farmers[0]!, 'png', true)).status, 415);
    assert.equal((await send(f.farmers[0]!, 'png', false, true)).status, 400);
    assert.equal(calls, 3);
  });
});
