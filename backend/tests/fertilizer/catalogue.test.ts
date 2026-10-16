import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import express from 'express';
import { productWrite, productRevision } from '../../src/modules/fertilizer/catalogue.types.js';
import {
  createProductService,
  productProjection,
} from '../../src/modules/fertilizer/catalogue.service.js';
import type {
  ProductRepository,
  ProductRecord,
} from '../../src/modules/fertilizer/catalogue.repository.js';
import { productRoutes } from '../../src/modules/fertilizer/catalogue.routes.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { memoryRepository } from '../auth/helpers.js';
import { memoryFertilizer, draftInput } from './helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';

test('standalone product intake requires reviewed source identity and valid nutrient units', () => {
  const draft = draftInput();
  const input = {
    product: draft.product,
    status: 'DRAFT',
    information: {
      type: null,
      growthStages: [],
      suitableConditions: [],
      applicationRateText: null,
      source: { ...draft.rule.source, url: draft.product.sourceReference },
      reviewNote: draft.rule.reviewNote,
      approved: true,
    },
  };
  assert.equal(productWrite.safeParse(input).success, true);
  for (const change of [
    { information: { ...input.information, approved: false } },
    { information: { ...input.information, source: draft.rule.source } },
    { product: { ...input.product, nitrogenPercent: '-1' } },
    { status: 'DELETED' },
    { inferredDose: 100 },
  ])
    assert.equal(productWrite.safeParse({ ...input, ...change }).success, false);
});

test('rule-linked products are visibly frozen and unreviewed legacy metadata cannot activate', async () => {
  const fertilizer = memoryFertilizer().rule.fertilizer;
  const row: ProductRecord = { ...fertilizer, _count: { rules: 1 }, knowledgeDocuments: [] };
  const result = productProjection(row);
  assert.equal(result.contentEditable, false);
  assert.equal(result.validForActivation, false);
  assert.equal(result.draftInput.information, null);
  assert.notEqual(productRevision(row, 1), productRevision(row, 2));
  const repository: ProductRepository = {
    async list() {
      return Array.from({ length: 101 }, () => ({ ...row, id: randomUUID() }));
    },
    async write() {
      return row;
    },
    async status() {
      return row;
    },
  };
  const page = await createProductService(repository).list();
  assert.equal(page.items.length, 100);
  assert.equal(page.nextCursor, page.items[99]?.id);
  const input = productWrite.parse({
    product: draftInput().product,
    status: 'DRAFT',
    information: {
      type: null,
      growthStages: [],
      suitableConditions: [],
      applicationRateText: null,
      source: { ...draftInput().rule.source, url: draftInput().product.sourceReference },
      reviewNote: draftInput().rule.reviewNote,
      approved: true,
    },
  });
  await assert.rejects(
    createProductService(repository).write(row.id, input, randomUUID(), 'request'),
  );
});

test('all standalone product catalogue operations reject farmers and guests before database access', async () => {
  const auth = createAuthService(testEnvironment, memoryRepository().repository);
  const password = 'synthetic catalogue password';
  await auth.register({ email: 'catalogue-farmer@example.invalid', password });
  const token = (await auth.login({ email: 'catalogue-farmer@example.invalid', password }))
    .accessToken;
  const unavailable = async (): Promise<never> => {
    throw new Error('unexpected database access');
  };
  const service = createProductService({
    list: unavailable,
    write: unavailable,
    status: unavailable,
  });
  const app = express();
  app.use(requestContext(silentLogger));
  app.use('/api/v1', productRoutes(auth, service));
  app.use(errorHandler(silentLogger));
  await withServer(app, async (base) => {
    for (const [method, path] of [
      ['GET', ''],
      ['POST', ''],
      ['PATCH', `/${randomUUID()}`],
      ['PATCH', `/${randomUUID()}/status`],
    ] as const) {
      for (const [headers, expected] of [
        [{}, 401],
        [{ Authorization: `Bearer ${token}` }, 403],
      ] as const) {
        assert.equal(
          (await fetch(`${base}/api/v1/admin/fertilizers${path}`, { method, headers })).status,
          expected,
        );
      }
    }
  });
});
