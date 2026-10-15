// Phase 23.7 actual services; the parent owns and validates the disposable schema.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import { createApp } from '../backend/src/app.ts';
import { loadEnvironment } from '../backend/src/config/environment.ts';
import { getDatabaseClient } from '../backend/src/database/client.ts';
import { createAccountsRepository } from '../backend/src/modules/admin/accounts.repository.ts';
import { createAccountsService } from '../backend/src/modules/admin/accounts.service.ts';
import { createAuthRepository } from '../backend/src/modules/auth/auth.repository.ts';
import { createAuthService } from '../backend/src/modules/auth/auth.service.ts';
import { createProfileRepository } from '../backend/src/modules/profile/profile.repository.ts';
import { createProfileService } from '../backend/src/modules/profile/profile.service.ts';
import { createProfileMediaRepository } from '../backend/src/modules/profile/profile-media.repository.ts';
import { createProfileMediaService } from '../backend/src/modules/profile/profile-media.service.ts';
import { createImageStorage } from '../backend/src/modules/scans/scan.storage.ts';
import { silentLogger } from '../backend/tests/foundation/helpers.ts';

const sharp = createRequire(new URL('../backend/package.json', import.meta.url))('sharp');

const schema = process.env.PHASE23_SCHEMA;
assert.match(schema ?? '', /^phase23_[a-f0-9]{32}$/);
assert.equal(process.env.PHASE23_DB_CONTEXT_LOADED, '1');
const environment = { ...loadEnvironment(), NODE_ENV: 'test', RATE_LIMIT_MAX: 3000 };
assert.equal(new URL(environment.DATABASE_URL).searchParams.get('schema'), schema);
const database = getDatabaseClient(environment.DATABASE_URL);
assert.equal((await database.$queryRaw`SELECT current_schema() AS schema`)[0].schema, schema);
const authRepository = createAuthRepository(database),
  auth = createAuthService(environment, authRepository);
const profiles = createProfileRepository(database),
  accounts = createAccountsRepository(database);
const realStorage = createImageStorage(environment, 'profiles'),
  assets = new Set();
assert.ok(realStorage.enabled);
const storage = {
  ...realStorage,
  async upload(image, publicId) {
    assets.add(publicId);
    return realStorage.upload(image, publicId);
  },
};
const media = createProfileMediaService(createProfileMediaRepository(database), storage);
const app = createApp(
  environment,
  silentLogger,
  {
    async checkDatabase() {
      await database.$queryRaw`SELECT 1`;
    },
  },
  authRepository,
  undefined,
  undefined,
  undefined,
  undefined,
  undefined,
  undefined,
  undefined,
  undefined,
  undefined,
  createProfileService(profiles),
  createAccountsService(accounts),
  media,
);
const server = createServer(app);
const proof = {
  passed: false,
  cloudCleanupComplete: false,
  physicalDevice: false,
  rawDatasetAccess: false,
  steps: [],
};
let stage = 'controlled accounts';
try {
  const credential = (kind) => ({
    email: `phase237-${kind}-${randomUUID()}@example.invalid`,
    password: `synthetic-${randomUUID()}`,
  });
  const farmer = credential('farmer'),
    other = credential('other'),
    admin = credential('admin');
  await auth.register(farmer);
  await auth.register(other);
  await auth.createAdmin(admin);
  const farmerGrant = await auth.login(farmer),
    otherGrant = await auth.login(other),
    adminGrant = await auth.login(admin);
  const ownerId = (await auth.authenticate(farmerGrant.accessToken)).userId;
  const otherId = (await auth.authenticate(otherGrant.accessToken)).userId;
  const adminId = (await auth.authenticate(adminGrant.accessToken)).userId;
  farmer.id = ownerId;
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  async function request(path, token, method = 'GET', body, expected = 200) {
    const response = await fetch(base + path, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        'X-Auth-Request': '1',
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      signal: AbortSignal.timeout(25000),
    });
    const value = await response.json();
    assert.equal(response.status, expected, `Unexpected HTTP status at ${path}`);
    return value.data;
  }
  stage = 'profile API isolation and validation';
  assert.equal((await request('/profile', farmerGrant.accessToken)).profile, null);
  const otherProfile = await request('/profile', otherGrant.accessToken, 'PATCH', {
    expectedRevision: null,
    displayName: 'Other fixture farmer',
  });
  for (const invalid of [
    { avatarPendingPublicId: 'invalid', avatarUploadStartedAt: new Date() },
    { avatarUploadStartedAt: new Date() },
    { avatarCleanupPublicIds: Array(9).fill('fixture') },
  ]) {
    await assert.rejects(
      database.farmerProfile.update({ where: { userId: otherId }, data: invalid }),
    );
  }
  assert.equal((await request('/profile', farmerGrant.accessToken)).profile, null);
  await request(`/profile?userId=${otherId}`, farmerGrant.accessToken, 'GET', undefined, 400);
  await request(
    '/profile',
    farmerGrant.accessToken,
    'PATCH',
    { expectedRevision: null, displayName: 'Attack', userId: otherId },
    400,
  );
  await request(
    '/profile',
    farmerGrant.accessToken,
    'PATCH',
    { expectedRevision: null, displayName: 'Attack', role: 'ADMIN' },
    400,
  );
  await request('/profile', adminGrant.accessToken, 'GET', undefined, 403);
  assert.equal(
    (await request('/profile', otherGrant.accessToken)).profile.revision,
    otherProfile.profile.revision,
  );
  stage = 'protected private-photo delivery and metadata removal';
  const createdProfile = await request('/profile', farmerGrant.accessToken, 'PATCH', {
    expectedRevision: null,
    displayName: 'Security fixture farmer',
  });
  const cameraImage = await sharp({
    create: { width: 24, height: 24, channels: 3, background: '#689746' },
  })
    .png()
    .withExif({
      IFD0: { Artist: 'PRIVATE_CAMERA_FIXTURE', ImageDescription: 'PRIVATE_LOCATION_FIXTURE' },
    })
    .toBuffer();
  const imageForm = new FormData();
  imageForm.append(
    'image',
    new Blob([cameraImage], { type: 'image/png' }),
    'owned-security-fixture.png',
  );
  imageForm.append('expectedRevision', createdProfile.profile.revision);
  const photoUpload = await fetch(`${base}/profile/avatar`, {
    method: 'POST',
    body: imageForm,
    headers: { Authorization: `Bearer ${farmerGrant.accessToken}`, 'X-Auth-Request': '1' },
  });
  assert.equal(photoUpload.status, 200);
  const photoProfile = (await photoUpload.json()).data.profile;
  assert.match(photoProfile.avatarUrl, /^profile\/avatar\?v=[a-f0-9]{64}$/);
  assert.equal(JSON.stringify(photoProfile).includes('res.cloudinary.com'), false);
  for (const [token, expected] of [
    [undefined, 401],
    [otherGrant.accessToken, 404],
    [adminGrant.accessToken, 403],
    [farmerGrant.accessToken, 200],
  ]) {
    const response = await fetch(`${base}/${photoProfile.avatarUrl}`, {
      headers: { 'X-Auth-Request': '1', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    });
    assert.equal(response.status, expected);
    if (expected === 200) {
      assert.equal(response.headers.get('cache-control'), 'private, no-store');
      const decoded = await sharp(Buffer.from(await response.arrayBuffer())).metadata();
      assert.equal(decoded.exif, undefined);
      assert.equal(decoded.xmp, undefined);
      assert.equal(decoded.iptc, undefined);
    }
  }
  await request('/profile/avatar', farmerGrant.accessToken, 'DELETE', {
    expectedRevision: photoProfile.revision,
  });
  // Restore this generated account's empty-profile precondition for the existing
  // Flutter creation journey; never touch a pre-existing account/profile.
  const securityProfile = await database.farmerProfile.findUniqueOrThrow({ where: { userId: ownerId } });
  assert.equal(securityProfile.avatarPublicId, null);
  assert.equal(securityProfile.avatarPendingPublicId, null);
  assert.deepEqual(securityProfile.avatarCleanupPublicIds, []);
  await database.farmerProfile.delete({ where: { userId: ownerId } });
  stage = 'Admin pagination, denial and non-secret audit projection';
  const seen = new Set();
  let cursor;
  do {
    const page = await request(
      `/admin/farmers?limit=1${cursor ? `&cursor=${cursor}` : ''}`,
      adminGrant.accessToken,
    );
    assert.ok(page.items.length <= 1);
    for (const row of page.items) {
      assert.equal(seen.has(row.id), false);
      assert.notEqual(row.id, adminId);
      assert.equal('passwordHash' in row, false);
      seen.add(row.id);
    }
    cursor = page.nextCursor;
  } while (cursor);
  assert.ok(seen.has(ownerId) && seen.has(otherId));
  for (const path of ['/admin/farmers', '/admin/audit-logs'])
    await request(path, farmerGrant.accessToken, 'GET', undefined, 403);
  await request(
    `/admin/farmers/${ownerId}/status`,
    farmerGrant.accessToken,
    'PATCH',
    { status: 'SUSPENDED', expectedRevision: 'a'.repeat(64) },
    403,
  );
  await request(
    `/admin/farmers/${adminId}/status`,
    adminGrant.accessToken,
    'PATCH',
    { status: 'SUSPENDED', expectedRevision: 'a'.repeat(64) },
    404,
  );
  await request('/admin/farmers?limit=51', adminGrant.accessToken, 'GET', undefined, 400);
  await request('/admin/audit-logs?from=2026-10-15', adminGrant.accessToken, 'GET', undefined, 400);
  const privateMarker = `PRIVATE_FIXTURE_${randomUUID()}`;
  const audit = await database.auditLog.create({
    data: {
      actorId: adminId,
      action: 'UPDATE',
      entityType: 'farmer_account',
      entityId: otherId,
      changes: {
        passwordHash: privateMarker,
        refreshToken: privateMarker,
        fields: { name: privateMarker },
        status: 'ACTIVE',
      },
    },
  });
  const auditPage = await request(
    `/admin/audit-logs?entityType=farmer_account&actorId=${adminId}`,
    adminGrant.accessToken,
  );
  assert.equal(JSON.stringify(auditPage).includes(privateMarker), false);
  await assert.rejects(
    database.auditLog.update({ where: { id: audit.id }, data: { changes: {} } }),
  );
  stage = 'transaction rollback when audit write fails';
  // This temporary trigger exists solely inside the verified disposable schema.
  await database.$executeRawUnsafe(
    `CREATE FUNCTION phase237_reject_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.entity_type='farmer_account' AND NEW.action='DEACTIVATE' THEN RAISE EXCEPTION 'fixture audit failure'; END IF; RETURN NEW; END $$`,
  );
  await database.$executeRawUnsafe(
    'CREATE TRIGGER phase237_reject_audit BEFORE INSERT ON audit_logs FOR EACH ROW EXECUTE FUNCTION phase237_reject_audit()',
  );
  const target = (
    await request(`/admin/farmers?email=${encodeURIComponent(other.email)}`, adminGrant.accessToken)
  ).items[0];
  await request(
    `/admin/farmers/${otherId}/status`,
    adminGrant.accessToken,
    'PATCH',
    { status: 'SUSPENDED', expectedRevision: target.revision },
    500,
  );
  assert.equal(
    (await database.user.findUniqueOrThrow({ where: { id: otherId } })).status,
    'ACTIVE',
  );
  assert.equal((await auth.authenticate(otherGrant.accessToken)).userId, otherId);
  await database.$executeRawUnsafe('DROP TRIGGER phase237_reject_audit ON audit_logs');
  await database.$executeRawUnsafe('DROP FUNCTION phase237_reject_audit()');
  stage = 'real Flutter profile, photos, restart and Admin widgets';
  const tooling = new Set([
    'PATH',
    'PATHEXT',
    'SYSTEMROOT',
    'WINDIR',
    'COMSPEC',
    'TEMP',
    'TMP',
    'USERPROFILE',
    'APPDATA',
    'LOCALAPPDATA',
    'PUB_CACHE',
    'FLUTTER_ROOT',
    'ANDROID_HOME',
    'ANDROID_SDK_ROOT',
    'JAVA_HOME',
    'CI',
    'TERM',
    'NO_COLOR',
    'FLUTTER_SUPPRESS_ANALYTICS',
    'DART_SUPPRESS_ANALYTICS',
  ]);
  const childEnvironment = Object.fromEntries(
    Object.entries(process.env).filter(([key]) => tooling.has(key.toUpperCase())),
  );
  await new Promise((resolve, reject) => {
    const child = spawn(
      process.env.PHASE23_DART,
      [
        process.env.PHASE23_FLUTTER_TOOLS,
        'test',
        '--no-pub',
        '--reporter=expanded',
        'test/integration/requirements_test.dart',
        '--dart-define=RUN_LIVE_REQUIREMENTS=true',
        `--dart-define=API_BASE_URL=${base}`,
      ],
      {
        cwd: new URL('../mobile/', import.meta.url),
        windowsHide: true,
        env: {
          ...childEnvironment,
          REQUIREMENTS_FARMER: JSON.stringify(farmer),
          REQUIREMENTS_ADMIN: JSON.stringify(admin),
        },
        stdio: 'inherit',
      },
    );
    child.once('error', reject);
    child.once('exit', (code) =>
      code === 0 ? resolve() : reject(new Error('Flutter requirements check failed')),
    );
  });
  stage = 'saved database outcomes, revocation and pending calculators/media';
  const saved = await database.farmerProfile.findUniqueOrThrow({ where: { userId: ownerId } });
  assert.equal(saved.displayName, 'Field Researcher');
  assert.equal(saved.region, 'Fixture Region');
  assert.equal(saved.countryCode, 'PK');
  assert.equal(saved.fieldAreaHectares.toString(), '1.2345');
  assert.equal(saved.avatarUrl, null);
  assert.equal(saved.avatarPendingPublicId, null);
  assert.deepEqual(saved.avatarCleanupPublicIds, []);
  const history = await database.auditLog.findMany({
    where: { entityType: 'farmer_account', entityId: ownerId },
  });
  assert.equal(history.length, 3);
  assert.ok(history.some((row) => row.action === 'ACTIVATE'));
  await request('/profile', farmerGrant.accessToken, 'GET', undefined, 401);
  const reactivateGrant = await auth.login(farmer);
  assert.equal(
    (await request('/profile', reactivateGrant.accessToken)).profile.displayName,
    'Field Researcher',
  );
  await auth.logout(reactivateGrant.refreshToken);
  const stale = history.find((row) => row.action === 'DEACTIVATE');
  assert.ok(stale);
  await request(
    `/admin/farmers/${ownerId}/status`,
    adminGrant.accessToken,
    'PATCH',
    { status: 'SUSPENDED', expectedRevision: 'a'.repeat(64) },
    409,
  );
  const audits = await request(
    `/admin/audit-logs?action=DEACTIVATE&entityType=farmer_account&actorId=${adminId}&limit=1`,
    adminGrant.accessToken,
  );
  assert.equal(audits.items.length, 1);
  assert.ok(audits.nextCursor);
  const next = await request(
    `/admin/audit-logs?action=DEACTIVATE&entityType=farmer_account&actorId=${adminId}&limit=1&cursor=${audits.nextCursor}`,
    adminGrant.accessToken,
  );
  assert.equal(next.items.length, 1);
  assert.notEqual(next.items[0].id, audits.items[0].id);
  assert.equal(
    (await request('/calculators/fertilizer/rules', farmerGrant.accessToken)).status,
    'PENDING_RULES',
  );
  assert.equal(
    (await request('/calculators/yield/configurations', farmerGrant.accessToken)).status,
    'PENDING_CONFIGURATION',
  );
  assert.equal(await database.diseaseImage.count(), 0);
  proof.passed = true;
  proof.steps = [
    'own-profile-api',
    'cross-farmer-denial',
    'strict-security-fields',
    'admin-only-access',
    'farmer-pagination',
    'redacted-immutable-audits',
    'real-transaction-rollback',
    'profile-form-persistence',
    'cloud-photo-replacement-and-removal',
    'logout-login-and-restart',
    'admin-confirmed-statuses',
    'session-revocation',
    'audit-ui-filters',
    'pending-real-calculator-content',
    'no-curated-media',
    'protected-image-delivery',
    'metadata-free-real-cloudinary',
    'no-cloudinary-url-disclosure',
  ];
} catch {
  console.error(`FAIL: ${stage}; private details omitted.`);
  process.exitCode = 1;
} finally {
  if (server.listening) await new Promise((resolve) => server.close(resolve));
  const cleanup = await Promise.allSettled([...assets].map((id) => realStorage.destroy(id)));
  proof.cloudCleanupComplete = cleanup.every((result) => result.status === 'fulfilled');
  proof.ownedCloudAssets = [...assets];
  if (!proof.cloudCleanupComplete) process.exitCode = 1;
  await writeFile(
    join(process.env.PHASE23_OUTPUT, 'requirements-proof.json'),
    JSON.stringify(proof, null, 2),
  );
  await database.$disconnect();
}
if (proof.passed && proof.cloudCleanupComplete)
  console.log(
    'PASS: Phase 23.7 actual PostgreSQL-backed profile/Admin APIs, Flutter widgets, private Cloudinary lifecycle and unchanged pending-content contracts.',
  );
