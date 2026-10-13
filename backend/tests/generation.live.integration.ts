import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { z } from 'zod';
import { createApp } from '../src/app.js';
import { loadEnvironment } from '../src/config/environment.js';
import { createDatabaseClient } from '../src/database/client.js';
import { createAuthRepository } from '../src/modules/auth/auth.repository.js';
import { createAuthService } from '../src/modules/auth/auth.service.js';
import { createGenerationClient } from '../src/modules/generation/generation.client.js';
import { createGenerationService } from '../src/modules/generation/generation.service.js';
import {
  type GenerationData,
  generationDataSchema,
  predictionContextSchema,
} from '../src/modules/generation/generation.types.js';
import { createHealthRepository } from '../src/modules/health/health.repository.js';
import { diseaseLabels } from '../src/modules/inference/inference.types.js';
import { createKnowledgeClient } from '../src/modules/knowledge/knowledge.client.js';
import { createKnowledgeRepository } from '../src/modules/knowledge/knowledge.repository.js';
import { createKnowledgeService } from '../src/modules/knowledge/knowledge.service.js';
import { knowledgeSourceSchema } from '../src/modules/knowledge/knowledge.types.js';
import { createScanRepository } from '../src/modules/scans/scan.repository.js';
import { createScanService } from '../src/modules/scans/scan.service.js';
import { scanResponse } from '../src/modules/scans/scan.types.js';
import { validateImage } from '../src/modules/scans/scan.validation.js';
import { silentLogger, withServer } from './foundation/helpers.js';
import { fakeInference, fakeStorage, imageFile } from './scans/helpers.js';

const successSchema = z.strictObject({
  success: z.literal(true),
  data: generationDataSchema,
  requestId: z.uuid(),
});
const digest = (value: string | Buffer) => createHash('sha256').update(value).digest('hex');
const lineages = {
  Common_Rust: [
    'maize-common-rust-',
    'https://extension.umn.edu/agriculture/crop-production/corn/common-rust-on-corn',
  ],
  Gray_Leaf_Spot: [
    'maize-gray-leaf-spot-',
    'https://extension.umn.edu/agriculture/crop-production/corn/gray-leaf-spot-on-corn',
  ],
  Healthy: [
    'maize-healthy-',
    'https://crops.extension.iastate.edu/encyclopedia/early-season-crop-scouting',
  ],
  Northern_Corn_Leaf_Blight: [
    'maize-northern-corn-leaf-blight-',
    'https://extension.umn.edu/agriculture/crop-production/corn/northern-corn-leaf-blight',
  ],
} as const;
type DiseaseLabel = (typeof diseaseLabels)[number];
type SafeCase = Pick<
  GenerationData,
  | 'status'
  | 'providerUsed'
  | 'generationModel'
  | 'promptVersion'
  | 'contextPolicyVersion'
  | 'reviewSetVersion'
  | 'durationMs'
> & { caseId: string; documentKeys: string[] };

test('real Node -> authenticated FastAPI -> Google -> PostgreSQL grounded explanations', {
  skip: process.env['RUN_LIVE_GENERATION'] !== '1',
  timeout: 240000,
}, async (t) => {
  const environment = { ...loadEnvironment(), GENERATION_RATE_LIMIT_MAX: 40 };
  assert.ok(environment.AI_SERVICE_URL, 'The opt-in check requires AI_SERVICE_URL.');
  assert.ok(environment.AI_SERVICE_TOKEN, 'The opt-in check requires AI_SERVICE_TOKEN.');
  const database = createDatabaseClient(environment.DATABASE_URL, 30000);
  const auth = createAuthRepository(database);
  const authService = createAuthService(environment, auth);
  const repository = createScanRepository(database);
  const cloud = fakeStorage();
  const scans = createScanService(repository, cloud.storage, silentLogger);
  const modelVersion = `phase15-fixture-${randomUUID()}`;
  const uploadIds = new Set<string>();
  const scanIds = new Set<string>();
  const accountEmails = new Set<string>();
  const durations: number[] = [];
  const cases: SafeCase[] = [];
  let failedCheck = false;
  const predicted = fakeInference({
    modelVersion,
    confidence: 0.99,
    topProbabilities: [
      { className: 'Common_Rust', probability: 0.99 },
      { className: 'Gray_Leaf_Spot', probability: 0.004 },
      { className: 'Healthy', probability: 0.003 },
      { className: 'Northern_Corn_Leaf_Blight', probability: 0.003 },
    ],
  }).result;
  const expectedPrediction = predictionContextSchema.parse({
    predictedClass: predicted.predictedClass,
    confidence: predicted.confidence,
    modelVersion: predicted.modelVersion,
    preprocessingVersion: predicted.preprocessingVersion,
    predictionStatus: predicted.predictionStatus,
    confidenceThreshold: predicted.confidenceThreshold,
    uncertaintyReason: predicted.uncertaintyReason,
  });

  async function farmer() {
    const credentials = {
      email: `phase15-live-${randomUUID()}@example.invalid`,
      password: `synthetic-test-${randomUUID()}`,
    };
    accountEmails.add(credentials.email);
    await authService.register(credentials);
    const account = await database.user.findUniqueOrThrow({ where: { email: credentials.email } });
    assert.equal(account.role, 'FARMER');
    const grant = await authService.login(credentials);
    return { id: account.id, access: grant.accessToken };
  }

  async function completedFixture(userId: string | null) {
    // These controlled scan/model/prediction fixtures exercise real persistence
    // and owner/capability reads. No Cloudinary upload or classifier fit is run.
    const key = randomUUID();
    const uploadId = randomUUID();
    uploadIds.add(uploadId);
    const image = await validateImage(await imageFile());
    const claimed = await repository.claim(
      digest(`${userId ?? 'anonymous'}:${key}`),
      digest(image.bytes),
      uploadId,
    );
    assert.equal(claimed.claimed, true);
    const pending = await repository.complete(uploadId, {
      userId,
      image,
      stored: {
        publicId: claimed.record.publicId,
        url: `https://example.invalid/phase15-synthetic/${uploadId}.png`,
        uploadedAt: new Date(),
      },
    });
    assert.ok(pending.scan);
    scanIds.add(pending.scan.id);
    const attempt = await repository.startInference(pending.scan.id);
    assert.ok(attempt);
    const completed = await repository.completeInference(pending.scan.id, attempt, predicted);
    assert.equal(completed.status, 'COMPLETED');
    assert.equal(completed.userId, userId);
    assert.equal(completed.predictions.length, 1);
    const saved = scanResponse(completed).prediction;
    assert.ok(saved);
    assert.deepEqual(
      predictionContextSchema.parse({
        predictedClass: saved.predictedClass,
        confidence: saved.confidence,
        modelVersion: saved.modelVersion,
        preprocessingVersion: saved.preprocessingVersion,
        predictionStatus: saved.predictionStatus,
        confidenceThreshold: saved.confidenceThreshold,
        uncertaintyReason: saved.uncertaintyReason,
      }),
      expectedPrediction,
    );
    return { id: completed.id, key };
  }

  function recordCase(caseId: string, result: GenerationData) {
    cases.push({
      caseId,
      status: result.status,
      providerUsed: result.providerUsed,
      generationModel: result.generationModel,
      promptVersion: result.promptVersion,
      contextPolicyVersion: result.contextPolicyVersion,
      reviewSetVersion: result.reviewSetVersion,
      durationMs: result.durationMs,
      documentKeys: result.sources.map((source) => source.documentKey),
    });
  }

  async function verifiedEvidence(result: GenerationData, label: DiseaseLabel) {
    assert.equal(result.status, 'GROUNDED');
    assert.equal(result.providerUsed, true);
    assert.ok(result.sources.length > 0);
    assert.equal(result.reviewSetVersion, 'maize-extension-20261012-v1');
    for (const source of result.sources) {
      const document = await database.knowledgeDocument.findUniqueOrThrow({
        where: { id: source.documentId },
        include: { chunks: { select: { id: true } } },
      });
      assert.equal(document.status, 'ACTIVE');
      assert.equal(document.documentKey, source.documentKey);
      assert.equal(document.version, source.documentVersion);
      const [prefix, sourceUrl] = lineages[label];
      assert.ok(document.documentKey.startsWith(prefix));
      const metadata = document.metadata;
      assert.ok(metadata && typeof metadata === 'object' && !Array.isArray(metadata));
      assert.deepEqual(source.source, knowledgeSourceSchema.parse(metadata['source']));
      assert.equal(source.source.url, sourceUrl);
      assert.ok(source.chunkIds.every((id) => document.chunks.some((chunk) => chunk.id === id)));
      const cited = result.sections.flatMap((section) =>
        section.items
          .filter((item) => item.sourceIds.includes(source.id))
          .map((item) => ({ topic: section.knowledgeType, text: item.text })),
      );
      assert.ok(cited.length > 0);
      for (const item of cited) {
        assert.equal(item.topic, document.knowledgeType);
        assert.equal(item.text, document.content.replace(/\r\n?/g, '\n').normalize('NFC').trim());
      }
    }
    durations.push(result.durationMs);
  }

  try {
    await database.modelVersion.create({
      data: {
        version: modelVersion,
        architecture: 'synthetic-explanation-fixture',
        artifactUri: `sha256:${digest(modelVersion)}`,
        artifactSha256: digest(modelVersion),
        datasetVersion: 'synthetic-only-no-dataset-read',
        preprocessingVersion: predicted.preprocessingVersion,
        classLabels: [...diseaseLabels],
        trainingConfig: { purpose: 'Controlled explanation fixture; not a trained artifact.' },
        status: 'VALIDATED',
      },
    });
    const owner = await farmer();
    const other = await farmer();
    const anonymous = await completedFixture(null);
    const owned = await completedFixture(owner.id);
    const app = createApp(
      environment,
      silentLogger,
      createHealthRepository(database),
      auth,
      scans,
      createKnowledgeService(
        createKnowledgeRepository(database),
        createKnowledgeClient(environment),
      ),
      createGenerationService(scans, createGenerationClient(environment)),
    );
    await withServer(app, async (base) => {
      async function post(path: string, body: object, headers: Record<string, string> = {}) {
        return fetch(`${base}/api/v1${path}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...headers },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(environment.GENERATION_TIMEOUT_MS + 5000),
        });
      }
      async function result(response: Response) {
        assert.equal(response.status, 200);
        assert.equal(response.headers.get('cache-control'), 'no-store');
        return successSchema.parse(await response.json()).data;
      }
      async function check(name: string, verify: () => Promise<void>) {
        await t.test(name, async () => {
          try {
            await verify();
          } catch (error) {
            failedCheck = true;
            throw error;
          }
        });
      }

      for (const [label, question] of [
        ['Common_Rust', 'What symptoms identify common rust in maize?'],
        ['Gray_Leaf_Spot', 'What symptoms identify gray leaf spot in maize?'],
        ['Northern_Corn_Leaf_Blight', 'What symptoms identify northern corn leaf blight in maize?'],
        ['Healthy', 'What symptoms should I look for when scouting healthy maize?'],
      ] as const) {
        await check(
          `known-source ${label} answer uses reviewed text and actual Google provider`,
          async () => {
            const answer = await result(
              await post('/knowledge/ask', {
                question,
                diseaseLabel: label,
                knowledgeType: 'SYMPTOMS',
              }),
            );
            assert.equal(answer.classifierPrediction, null);
            assert.ok(
              answer.sources.every(
                (source) => source.documentKey === `${lineages[label][0]}symptoms`,
              ),
            );
            await verifiedEvidence(answer, label);
            recordCase(`ask-${label}-symptoms`, answer);
          },
        );
      }
      await check(
        'unrelated and unavailable Healthy requests explicitly abstain without Gemini',
        async () => {
          for (const [caseId, question, expectedStatus] of [
            ['unrelated', 'Who is the president?', 'OUT_OF_SCOPE'],
            [
              'healthy-management-unavailable',
              'How do I treat healthy maize?',
              'INSUFFICIENT_INFORMATION',
            ],
            [
              'healthy-causes-unavailable',
              'What causes healthy maize?',
              'INSUFFICIENT_INFORMATION',
            ],
            [
              'healthy-conditions-unavailable',
              'What weather conditions favor healthy maize?',
              'INSUFFICIENT_INFORMATION',
            ],
          ] as const) {
            const answer = await result(await post('/knowledge/ask', { question }));
            assert.equal(answer.status, expectedStatus);
            assert.equal(answer.providerUsed, false);
            assert.equal(answer.classifierPrediction, null);
            assert.deepEqual(answer.sections, []);
            assert.deepEqual(answer.sources, []);
            recordCase(caseId, answer);
          }
        },
      );
      await check(
        'anonymous explanation needs the original capability and preserves uncertainty',
        async () => {
          const path = `/scans/${anonymous.id}/explanation`;
          assert.equal((await post(path, {})).status, 401);
          assert.equal((await post(path, {}, { 'Idempotency-Key': randomUUID() })).status, 404);
          const answer = await result(await post(path, {}, { 'Idempotency-Key': anonymous.key }));
          assert.deepEqual(answer.classifierPrediction, expectedPrediction);
          assert.ok(answer.warnings.some((warning) => warning.includes('LOW_CONFIDENCE')));
          await verifiedEvidence(answer, 'Common_Rust');
          recordCase('anonymous-scan-explanation', answer);
        },
      );
      await check(
        'farmer explanation uses persisted ownership and rejects another farmer',
        async () => {
          const path = `/scans/${owned.id}/explanation`;
          assert.equal((await post(path, {})).status, 401);
          assert.equal(
            (await post(path, {}, { Authorization: `Bearer ${other.access}` })).status,
            404,
          );
          const before = await repository.findScan(owned.id);
          const answer = await result(
            await post(path, {}, { Authorization: `Bearer ${owner.access}` }),
          );
          assert.deepEqual(answer.classifierPrediction, expectedPrediction);
          assert.ok(answer.warnings.some((warning) => warning.includes('LOW_CONFIDENCE')));
          await verifiedEvidence(answer, 'Common_Rust');
          recordCase('farmer-scan-explanation', answer);
          assert.deepEqual(await repository.findScan(owned.id), before);
        },
      );
      await check('public callers cannot substitute a classifier payload', async () => {
        assert.equal(
          (
            await post(
              `/scans/${anonymous.id}/explanation`,
              { prediction: expectedPrediction },
              {
                'Idempotency-Key': anonymous.key,
              },
            )
          ).status,
          400,
        );
        assert.equal(
          (
            await post('/knowledge/ask', {
              question: 'What symptoms identify common rust in maize?',
              prediction: expectedPrediction,
            })
          ).status,
          400,
        );
      });
    });
    assert.equal(failedCheck, false, 'All live checks must pass before reporting success.');
    assert.equal(cases.length, 10);
    assert.equal(durations.length, 6);
    assert.equal(cloud.assets.size, 0);
  } finally {
    try {
      const journals = await database.scanUpload.findMany({
        where: { id: { in: [...uploadIds] } },
      });
      for (const journal of journals) if (journal.scanId) scanIds.add(journal.scanId);
      await database.$transaction(
        async (transaction) => {
          await transaction.scanUpload.deleteMany({ where: { id: { in: [...uploadIds] } } });
          await transaction.scanPrediction.deleteMany({ where: { scanId: { in: [...scanIds] } } });
          await transaction.scan.deleteMany({ where: { id: { in: [...scanIds] } } });
          await transaction.modelVersion.deleteMany({ where: { version: modelVersion } });
          await transaction.user.deleteMany({ where: { email: { in: [...accountEmails] } } });
        },
        { maxWait: 10000, timeout: 30000 },
      );
    } finally {
      await database.$disconnect();
    }
  }
  console.log(
    JSON.stringify({
      liveGeneration: 'PASS',
      evaluatedAt: new Date().toISOString(),
      groundedProviderCalls: durations.length,
      representativeMeanMs: durations.reduce((sum, value) => sum + value, 0) / durations.length,
      representativeMinMs: Math.min(...durations),
      representativeMaxMs: Math.max(...durations),
      cases,
      scanFixtures: 'controlled persisted synthetic predictions; not live classifier outputs',
      ownership: 'anonymous capability and two real FARMER accounts',
      noDatasetReads: true,
      cloudinaryAssetsCreated: 0,
      fixtureCleanup: 'completed',
      noClassAccuracyClaim: true,
    }),
  );
});
