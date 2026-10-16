import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import express from 'express';
import { AppError } from '../../src/errors/app-error.js';
import { Prisma, type PrismaClient } from '../../src/generated/prisma/client.js';
import { createReferenceRepository } from '../../src/modules/knowledge/media.repository.js';
import { createReferenceService } from '../../src/modules/knowledge/media.service.js';
import { referenceMetadata, referenceRevision } from '../../src/modules/knowledge/media.types.js';
import type {
  ReferenceRecord,
  ReferenceRepository,
} from '../../src/modules/knowledge/media.repository.js';
import type { ImageStorage, ValidatedImage } from '../../src/modules/scans/scan.types.js';
import { knowledgeDraft } from '../admin/management.helpers.js';
import { referenceRoutes } from '../../src/modules/knowledge/media.routes.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { memoryRepository } from '../auth/helpers.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { imageFile } from '../scans/helpers.js';

test('reference persistence diagnostics expose only an allowlisted code and preserve the original error', async () => {
  const captured: unknown[] = [];
  const error = new Prisma.PrismaClientKnownRequestError('private query and submitted content', {
    code: 'P2028',
    clientVersion: 'test',
  });
  const database = {
    async $transaction() {
      throw error;
    },
  } as unknown as PrismaClient;
  const repository = createReferenceRepository(database, {
    warn: (event: unknown) => {
      captured.push(event);
    },
  });
  await assert.rejects(
    repository.finish(randomUUID(), 'https://example.invalid/private'),
    (e) => e === error,
  );
  assert.deepEqual(captured, [{ event: 'reference_database_failed', code: 'P2028' }]);
  assert.equal(JSON.stringify(captured).includes('private'), false);
});
function fixture(allowSynthetic = false) {
  const rows = new Map<string, ReferenceRecord>(),
    assets = new Set<string>();
  let tick = 1;
  const state = { uploadFails: false, deleteFails: false, ackLoss: false };
  const repository: ReferenceRepository = {
    async read(id) {
      return rows.get(id) ?? null;
    },
    async list(slug, admin) {
      return [...rows.values()].filter(
        (row) => row.disease.slug === slug && (admin || row.status === 'ACTIVE'),
      );
    },
    async reserve(id, publicId, input) {
      const row: ReferenceRecord = {
        id,
        diseaseId: randomUUID(),
        imageUrl: null,
        cloudinaryPublicId: publicId,
        altText: input.altText,
        sortOrder: input.sortOrder,
        provenance: input.provenance,
        status: 'DRAFT',
        uploadState: 'UPLOADING',
        cleanupPending: false,
        replacementFor: input.replacementFor ?? null,
        createdAt: new Date(),
        updatedAt: new Date(tick++),
        disease: { slug: input.diseaseSlug, status: 'ACTIVE' },
      };
      rows.set(id, row);
      return row;
    },
    async finish(id, url) {
      const row = rows.get(id)!;
      row.imageUrl = url;
      row.uploadState = 'READY';
      if (state.ackLoss) throw new Error('ack lost');
    },
    async mutate(id, revision, _actor, _request, change) {
      const row = rows.get(id);
      if (!row) throw new AppError('NOT_FOUND');
      if (row.uploadState !== 'READY' || row.cleanupPending || referenceRevision(row) !== revision)
        throw new AppError('CONFLICT');
      const data = change(row);
      if (typeof data.status === 'string') row.status = data.status;
      if (typeof data.altText === 'string') row.altText = data.altText;
      if (typeof data.sortOrder === 'number') row.sortOrder = data.sortOrder;
      if (typeof data.uploadState === 'string') row.uploadState = data.uploadState;
      if (typeof data.cleanupPending === 'boolean') row.cleanupPending = data.cleanupPending;
      if (data.provenance) row.provenance = data.provenance as Prisma.JsonValue;
      row.updatedAt = new Date(tick++);
      return row;
    },
    async cleanupCandidates() {
      for (const row of rows.values())
        if (row.uploadState === 'UPLOADING') {
          row.status = 'INACTIVE';
          row.uploadState = 'RETIRED';
          row.cleanupPending = true;
        }
      return [...rows.values()].filter((row) => row.cleanupPending);
    },
    async cleared(id) {
      const row = rows.get(id)!;
      row.cleanupPending = false;
      row.imageUrl = null;
    },
  };
  const storage: ImageStorage = {
    enabled: true,
    async upload(_image, id) {
      assets.add(id);
      if (state.uploadFails) throw new AppError('UPLOAD_FAILED');
      return {
        publicId: id,
        url: `https://res.cloudinary.com/fixture/image/authenticated/${id}.png`,
        uploadedAt: new Date(),
      };
    },
    async destroy(id) {
      if (state.deleteFails) throw new AppError('UPLOAD_FAILED');
      assets.delete(id);
    },
  };
  const input = referenceMetadata.parse({
    diseaseSlug: 'common-rust',
    altText: 'Synthetic test drawing',
    sortOrder: 1,
    provenance: {
      source: knowledgeDraft().source,
      license: 'Synthetic fixture only',
      contributor: 'Test generator',
      attribution: 'Synthetic, not agricultural evidence',
      rightsConfirmed: true,
      contentKind: 'SYNTHETIC_TEST',
    },
  });
  const image: ValidatedImage = {
    bytes: Buffer.from('fixture'),
    mimeType: 'image/png',
    width: 32,
    height: 32,
    orientation: 1,
  };
  return {
    service: createReferenceService(repository, storage, allowSynthetic),
    repository,
    rows,
    assets,
    state,
    input,
    image,
  };
}
test('reference image source/license/alt/order admission rejects incomplete provenance and internal fields', () => {
  const f = fixture();
  for (const change of [
    { altText: '' },
    { sortOrder: -1 },
    { provenance: { ...f.input.provenance, license: '' } },
    {
      provenance: {
        ...f.input.provenance,
        source: { ...f.input.provenance.source, url: 'http://example.invalid' },
      },
    },
    { cloudinaryPublicId: 'user supplied' },
  ])
    assert.equal(referenceMetadata.safeParse({ ...f.input, ...change }).success, false);
});
test('real public workflow refuses synthetic publication and incomplete rights attestation', async () => {
  const f = fixture();
  const row = await f.service.upload(f.input, f.image, randomUUID(), randomUUID());
  await assert.rejects(
    f.service.status(
      row.id,
      {
        status: 'ACTIVE',
        expectedRevision: row.revision,
        reviewNote: 'Synthetic publication must never enter the real catalogue.',
      },
      randomUUID(),
      randomUUID(),
    ),
  );
  assert.deepEqual((await f.service.list('common-rust')).items, []);
  await assert.rejects(f.service.imageLocation(row.id));
  assert.ok(await f.service.imageLocation(row.id, true));
});
test('isolated synthetic lifecycle publishes with attribution, reorders via draft and excludes hidden images', async () => {
  const f = fixture(true),
    actor = randomUUID(),
    request = randomUUID();
  const draft = await f.service.upload(f.input, f.image, actor, request);
  const published = await f.service.status(
    draft.id,
    {
      status: 'ACTIVE',
      expectedRevision: draft.revision,
      reviewNote: 'Explicit isolated synthetic test publication, not real disease evidence.',
    },
    actor,
    request,
  );
  assert.equal((await f.service.list('common-rust')).items.length, 1);
  assert.equal(published.provenance?.contentKind, 'SYNTHETIC_TEST');
  assert.ok(published.imagePath?.startsWith('admin/disease-images/'));
  assert.ok(
    (await f.service.imageLocation(draft.id)).publicId.startsWith('maizedoctor/references/'),
  );
  const reordered = await f.service.edit(
    draft.id,
    {
      altText: f.input.altText,
      sortOrder: 9,
      provenance: f.input.provenance,
      expectedRevision: published.revision,
    },
    actor,
    request,
  );
  assert.equal(reordered.sortOrder, 9);
  assert.equal(reordered.status, 'DRAFT');
  await assert.rejects(f.service.imageLocation(draft.id));
  await assert.rejects(
    f.service.status(
      draft.id,
      {
        status: 'ACTIVE',
        expectedRevision: published.revision,
        reviewNote: 'Stale publication must be rejected.',
      },
      actor,
      request,
    ),
  );
});
test('retirement responds before deletion; failed/interrupted recovery retains durable intent', async () => {
  const f = fixture(),
    actor = randomUUID(),
    request = randomUUID();
  const draft = await f.service.upload(f.input, f.image, actor, request);
  f.state.deleteFails = true;
  await f.service.status(
    draft.id,
    {
      status: 'DELETED',
      expectedRevision: draft.revision,
      reviewNote: 'Retire this isolated test asset safely.',
    },
    actor,
    request,
  );
  assert.equal(f.assets.size, 1);
  assert.deepEqual(await f.service.cleanup(), { removed: 0, failed: 1 });
  f.state.deleteFails = false;
  assert.deepEqual(await f.service.cleanup(), { removed: 1, failed: 0 });
  assert.equal(f.assets.size, 0);
  assert.deepEqual(await f.service.cleanup(), { removed: 0, failed: 0 });
});
test('upload acknowledgement loss retains completed draft and ambiguous upload stays recoverable', async () => {
  const f = fixture();
  f.state.ackLoss = true;
  const row = await f.service.upload(f.input, f.image, randomUUID(), randomUUID());
  assert.ok(row.imagePath);
  f.state.uploadFails = true;
  await assert.rejects(f.service.upload(f.input, f.image, randomUUID(), randomUUID()));
  assert.equal(f.assets.size, 2);
  await f.service.cleanup();
  assert.equal(f.assets.size, 1);
  assert.ok((await f.service.imageLocation(row.id, true)).url);
});

test('all reference administration routes deny guests/farmers; upload decoding and draft reads obey access policy', async () => {
  const f = fixture(),
    auth = createAuthService(testEnvironment, memoryRepository().repository),
    password = 'synthetic test password';
  await auth.createAdmin({ email: 'media-admin@example.invalid', password });
  await auth.register({ email: 'media-farmer@example.invalid', password });
  const admin = (await auth.login({ email: 'media-admin@example.invalid', password })).accessToken;
  const farmer = (await auth.login({ email: 'media-farmer@example.invalid', password }))
    .accessToken;
  const app = express();
  app.use(requestContext(silentLogger));
  app.use(express.json());
  app.use(
    '/api/v1',
    referenceRoutes(auth, f.service, async () => ({
      bytes: Buffer.from('fixture'),
      mimeType: 'image/png',
    })),
  );
  app.use(errorHandler(silentLogger));
  await withServer(app, async (base) => {
    for (const [method, path] of [
      ['GET', '/admin/disease-images/common-rust/items'],
      ['GET', `/admin/disease-images/${randomUUID()}/image`],
      ['POST', '/admin/disease-images'],
      ['PATCH', `/admin/disease-images/${randomUUID()}`],
      ['PATCH', `/admin/disease-images/${randomUUID()}/status`],
    ] as const) {
      for (const [token, status] of [
        [null, 401],
        [farmer, 403],
      ] as const)
        assert.equal(
          (
            await fetch(`${base}/api/v1${path}`, {
              method,
              headers: {
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
                'X-Auth-Request': '1',
              },
            })
          ).status,
          status,
        );
    }
    const decoded = await imageFile('png');
    async function upload(bytes: Buffer, metadata: unknown = f.input) {
      const form = new FormData();
      form.set('metadata', JSON.stringify(metadata));
      form.set('image', new Blob([new Uint8Array(bytes)], { type: 'image/png' }), 'reference.png');
      return fetch(`${base}/api/v1/admin/disease-images`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${admin}`, 'X-Auth-Request': '1' },
        body: form,
      });
    }
    assert.equal((await upload(Buffer.from('broken'))).status, 415);
    assert.equal((await upload(decoded.buffer, { ...f.input, provenance: {} })).status, 400);
    const created = await upload(decoded.buffer);
    assert.equal(created.status, 201);
    const row = (await created.json()).data;
    assert.equal((await fetch(`${base}/api/v1/disease-images/${row.id}/image`)).status, 404);
    assert.equal(
      (
        await fetch(`${base}/api/v1/admin/disease-images/${row.id}/image`, {
          headers: { Authorization: `Bearer ${admin}` },
        })
      ).status,
      200,
    );
    assert.equal(JSON.stringify(row).includes('res.cloudinary.com'), false);
  });
});
