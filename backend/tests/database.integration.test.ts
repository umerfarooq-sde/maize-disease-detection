import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import test from 'node:test';
import { createDatabaseClient, databaseConnectionUrl } from '../src/database/client.js';
import { applicationTables, assertSqlRejects, rollbackFixture } from './database-support.js';

const hash = (content: string): string => createHash('sha256').update(content, 'utf8').digest('hex');

test('database catalog matches the committed relational and SQL invariants', async () => {
  const prisma = createDatabaseClient();
  const schema = databaseConnectionUrl().searchParams.get('schema') ?? 'public';
  try {
    const tables = await prisma.$queryRaw<{ tablename: string }[]>`
      SELECT tablename FROM pg_tables WHERE schemaname = ${schema}
    `;
    for (const table of applicationTables) assert.ok(tables.some((row) => row.tablename === table), table);
    const nullable = await prisma.$queryRaw<{ is_nullable: string }[]>`
      SELECT is_nullable FROM information_schema.columns
      WHERE table_schema=${schema} AND table_name='scans' AND column_name='user_id'
    `;
    assert.equal(nullable[0]?.is_nullable, 'YES');
    const checks = await prisma.$queryRaw<{ count: bigint }[]>`
      SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
      WHERE n.nspname=${schema} AND c.contype='c'
    `;
    assert.equal(checks[0]?.count, 19n);
    const triggers = await prisma.$queryRaw<{ count: bigint }[]>`
      SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=${schema} AND NOT t.tgisinternal
    `;
    assert.equal(triggers[0]?.count, 33n);
    const indexes = await prisma.$queryRaw<{ indexname: string }[]>`
      SELECT indexname FROM pg_indexes WHERE schemaname=${schema} AND indexdef LIKE '% WHERE %'
    `;
    assert.deepEqual(indexes.map((row) => row.indexname).sort(), [
      'calculator_configs_one_active_idx', 'fertilizer_rules_one_active_idx',
      'knowledge_documents_one_active_idx', 'model_versions_one_production_idx',
    ]);
    const extension = await prisma.$queryRaw<{ extversion: string }[]>`
      SELECT extversion FROM pg_extension WHERE extname='vector'
    `;
    assert.ok(extension[0]?.extversion, 'pgvector must be installed');
  } finally {
    await prisma.$disconnect();
  }
});

test('Prisma round trips all 19 tables and PostgreSQL rejects invalid data; fixtures roll back',
  { timeout: 180000 }, async (t) => {
    const prisma = createDatabaseClient();
    const fixture = randomUUID();
    let userId: string | undefined;
    try {
      await assert.rejects(prisma.$transaction(async (tx) => {
        const user = await tx.user.create({ data: {
          email: `phase2-${fixture}@example.invalid`, passwordHash: 'synthetic-hash-for-rollback-only',
          farmerProfile: { create: { displayName: 'Synthetic farmer', countryCode: 'PK', fieldAreaHectares: '1.25' } },
        }, include: { farmerProfile: true } });
        userId = user.id;
        const otherUser = await tx.user.create({ data: {
          email: `phase2-other-${fixture}@example.invalid`, passwordHash: 'synthetic-hash-for-rollback-only',
        } });
        const admin = await tx.user.create({ data: {
          email: `phase2-admin-${fixture}@example.invalid`, passwordHash: 'synthetic-hash-for-rollback-only', role: 'ADMIN',
        } });
        const disease = await tx.disease.create({ data: {
          slug: `fixture-${fixture}`, name: 'Synthetic class, not agricultural advice', description: 'Rollback fixture',
          images: { create: { imageUrl: 'https://example.invalid/fixture.png', cloudinaryPublicId: `fixture/${fixture}/disease`, altText: 'Synthetic image' } },
          sources: { create: { title: 'Synthetic source', citation: 'Integration fixture; no factual agricultural content' } },
        }, include: { images: true, sources: true } });
        const fertilizer = await tx.fertilizer.create({ data: {
          slug: `fixture-${fixture}`, name: 'Synthetic fertilizer', description: 'Rollback fixture',
          nitrogenPercent: '1.00', phosphorusPercent: '2.00', potassiumPercent: '3.00',
          sourceReference: 'Integration fixture only', rules: { create: {
            ruleKey: 'fixture', version: 1, parameters: {}, unit: 'kg/ha', sourceReference: 'Integration fixture only', status: 'ACTIVE',
          } },
        }, include: { rules: true } });
        const calculator = await tx.calculatorConfig.create({ data: {
          kind: 'FERTILIZER', configKey: fixture, version: 1, parameters: {}, unit: 'kg/ha',
          sourceReference: 'Integration fixture only', createdById: admin.id, status: 'ACTIVE',
        } });
        const content = 'Synthetic knowledge content used only by database tests.';
        const document = await tx.knowledgeDocument.create({ data: {
          documentKey: fixture, version: 1, title: 'Synthetic document', content, contentHash: hash(content),
          sourceReference: 'Integration fixture only', topic: 'DISEASE', diseaseId: disease.id,
          createdById: admin.id, status: 'ACTIVE', chunks: { create: {
            chunkIndex: 0, content, contentHash: hash(content), tokenCount: 12,
          } },
        }, include: { chunks: true } });
        const chunk = document.chunks[0];
        assert.ok(chunk);
        const model = await tx.modelVersion.create({ data: {
          version: `fixture-${fixture}`, architecture: 'synthetic', artifactUri: `fixture://${fixture}/v1`,
          artifactSha256: hash('synthetic artifact'), datasetVersion: 'synthetic', preprocessingVersion: 'synthetic-v1',
          classLabels: ['fixture_disease', 'fixture_healthy'], trainingConfig: {},
        } });
        const secondModel = await tx.modelVersion.create({ data: {
          version: `fixture-v2-${fixture}`, architecture: 'synthetic', artifactUri: `fixture://${fixture}/v2`,
          artifactSha256: hash('second synthetic artifact'), datasetVersion: 'synthetic', preprocessingVersion: 'synthetic-v1',
          classLabels: ['fixture_disease', 'fixture_healthy'], trainingConfig: {},
        } });
        const scanData = {
          imageUrl: 'https://example.invalid/fixture.png', imageMimeType: 'image/png', imageBytes: 42,
        };
        const scan = await tx.scan.create({ data: {
          ...scanData, userId: user.id, cloudinaryPublicId: `fixture/${fixture}/scan`,
        } });
        const anonymousScan = await tx.scan.create({ data: {
          ...scanData, cloudinaryPublicId: `fixture/${fixture}/anonymous`,
        } });
        const prediction = await tx.scanPrediction.create({ data: {
          scanId: scan.id, modelVersionId: model.id, diseaseId: disease.id,
          predictedClass: 'fixture_disease', confidence: 0.8,
          probabilities: { fixture_disease: 0.8, fixture_healthy: 0.2 },
        } });
        await tx.scanPrediction.create({ data: {
          scanId: scan.id, modelVersionId: secondModel.id, predictedClass: 'fixture_healthy', confidence: 0.9,
          probabilities: { fixture_disease: 0.1, fixture_healthy: 0.9 },
        } });
        const metric = await tx.modelMetric.create({ data: {
          modelVersionId: model.id, split: 'TEST', datasetVersion: 'synthetic', sampleCount: 2,
          accuracy: 1, precision: 1, recall: 1, f1: 1, loss: 0,
          confusionMatrix: [[1, 0], [0, 1]], perClassMetrics: { fixture_disease: { f1: 1 } },
          learningCurves: { trainingLoss: [0.2], validationLoss: [0.3], trainingAccuracy: [1], validationAccuracy: [1] },
          evaluatedAt: new Date(),
        } });
        const query = await tx.aiQuery.create({ data: {
          userId: user.id, scanId: scan.id, diseaseId: disease.id, kind: 'DISEASE', question: 'Synthetic question?',
        } });
        await tx.aiQuery.create({ data: { scanId: anonymousScan.id, question: 'Anonymous fixture question?' } });
        const response = await tx.aiResponse.create({ data: {
          queryId: query.id, status: 'INSUFFICIENT_INFORMATION', answer: 'No sourced information in this fixture.',
          providerModel: 'synthetic-no-provider-call', processingMs: 0,
        } });
        const audit = await tx.auditLog.create({ data: {
          actorId: admin.id, action: 'CREATE', entityType: 'disease', entityId: disease.id, changes: { fixture: true },
        } });
        const notification = await tx.notification.create({ data: {
          userId: user.id, scanId: scan.id, kind: 'SCAN_READY', title: 'Synthetic notification', message: 'Rollback fixture',
        } });
        const history = await tx.history.create({ data: { userId: user.id, kind: 'SCAN', scanId: scan.id } });
        await tx.history.create({ data: { userId: user.id, kind: 'AI_QUESTION', aiQueryId: query.id } });
        await tx.history.create({ data: {
          userId: user.id, kind: 'FERTILIZER_CALCULATION', calculatorConfigId: calculator.id,
          snapshot: { inputs: {}, result: {}, unit: 'kg/ha' },
        } });

        await t.test('anonymous and farmer scans, nested relations, decimals, and model history round trip', async () => {
          assert.equal(anonymousScan.userId, null);
          assert.equal(user.farmerProfile?.fieldAreaHectares?.toString(), '1.25');
          assert.equal(fertilizer.phosphorusPercent.toString(), '2');
          assert.equal(disease.images.length, 1);
          assert.equal(disease.sources.length, 1);
          const loaded = await tx.scan.findUniqueOrThrow({ where: { id: scan.id }, include: {
            predictions: { include: { modelVersion: true, disease: true } }, history: true,
          } });
          assert.equal(loaded.predictions.length, 2);
          assert.ok(loaded.predictions.some((row) => row.modelVersion.id === model.id && row.disease?.id === disease.id));
          assert.equal(loaded.history[0]?.userId, user.id);
        });
        const rejects = (sql: string, values: unknown[], code: string | string[] = '23514'): Promise<void> => assertSqlRejects(tx, sql, values, code);
        await t.test('normalized unique account identity and farmer role constraints', async () => {
          await rejects('INSERT INTO users (email,password_hash) VALUES ($1,$2)', [user.email, 'fixture'], '23505');
          await rejects('INSERT INTO users (email,password_hash) VALUES ($1,$2)', [user.email.toUpperCase(), 'fixture']);
          await rejects('INSERT INTO farmer_profiles (user_id,display_name) VALUES ($1,$2)', [admin.id, 'Fixture']);
          await rejects("UPDATE users SET role='ADMIN' WHERE id=$1", [user.id]);
          await rejects('UPDATE farmer_profiles SET field_area_hectares=-1 WHERE user_id=$1', [user.id]);
        });
        await t.test('scan file metadata, lifecycle, owner identity, and owner deletion are protected', async () => {
          await rejects("INSERT INTO scans (user_id,image_url,cloudinary_public_id,image_mime_type,image_bytes) VALUES ($1,'fixture',$2,'image/png',42)", [admin.id, `fixture/${fixture}/admin`]);
          await rejects('UPDATE scans SET image_bytes=-1 WHERE id=$1', [scan.id]);
          await rejects("UPDATE scans SET status='COMPLETED' WHERE id=$1", [scan.id]);
          await rejects('UPDATE scans SET user_id=$1 WHERE id=$2', [user.id, anonymousScan.id]);
          await rejects('DELETE FROM users WHERE id=$1', [user.id], ['23001', '23503']);
          await tx.scan.update({ where: { id: scan.id }, data: { status: 'COMPLETED', finishedAt: new Date(), processingTimeMs: 3 } });
        });
        await t.test('history and notifications reject other farmer or anonymous targets', async () => {
          await rejects("INSERT INTO history (user_id,kind,scan_id) VALUES ($1,'SCAN',$2)", [otherUser.id, anonymousScan.id], '23503');
          await rejects("INSERT INTO notifications (user_id,scan_id,title,message) VALUES ($1,$2,'fixture','fixture')", [otherUser.id, scan.id], '23503');
          await rejects("INSERT INTO history (user_id,kind) VALUES ($1,'SCAN')", [user.id]);
          await rejects('UPDATE history SET snapshot=$1::jsonb WHERE id=$2', ['{"changed":true}', history.id]);
          await rejects("INSERT INTO history (user_id,kind,calculator_config_id) VALUES ($1,'YIELD_CALCULATION',$2)", [user.id, calculator.id]);
          await tx.notification.update({ where: { id: notification.id }, data: { readAt: new Date() } });
        });
        await t.test('model artifacts and predictions are immutable, bounded, and class-mapped', async () => {
          await rejects('UPDATE model_versions SET artifact_uri=$1 WHERE id=$2', ['fixture://overwrite', model.id]);
          await rejects('UPDATE scan_predictions SET confidence=0.2 WHERE id=$1', [prediction.id]);
          await rejects("INSERT INTO scan_predictions (scan_id,model_version_id,predicted_class,confidence,probabilities) VALUES ($1,$2,'unknown',0.8,$3::jsonb)", [anonymousScan.id, model.id, '{"fixture_disease":0.8,"fixture_healthy":0.2}']);
          await rejects("INSERT INTO scan_predictions (scan_id,model_version_id,predicted_class,confidence,probabilities) VALUES ($1,$2,'fixture_disease',0.8,$3::jsonb)", [anonymousScan.id, model.id, '{"fixture_disease":0.8,"fixture_healthy":0.3}']);
          await rejects("INSERT INTO scan_predictions (scan_id,model_version_id,predicted_class,confidence,probabilities) VALUES ($1,$2,'fixture_disease',0.7,$3::jsonb)", [anonymousScan.id, model.id, '{"fixture_disease":0.8,"fixture_healthy":0.2}']);
          await rejects('DELETE FROM model_versions WHERE id=$1', [model.id], ['23001', '23503']);
          await rejects('UPDATE model_metrics SET accuracy=1.1 WHERE id=$1', [metric.id]);
        });
        await t.test('only one production model can be selected without replacing previous artifacts', async () => {
          const currentProduction = await tx.modelVersion.findFirst({ where: { status: 'PRODUCTION' } });
          if (currentProduction) {
            await rejects("UPDATE model_versions SET status='PRODUCTION' WHERE id=$1", [model.id], '23505');
            return;
          }
          await tx.modelVersion.update({ where: { id: model.id }, data: { status: 'PRODUCTION' } });
          await rejects("UPDATE model_versions SET status='PRODUCTION' WHERE id=$1", [secondModel.id], '23505');
          await tx.modelVersion.update({ where: { id: model.id }, data: { status: 'RETIRED' } });
          await tx.modelVersion.update({ where: { id: secondModel.id }, data: { status: 'PRODUCTION' } });
        });
        await t.test('knowledge hash, source, version, and embedding dimensions are enforced', async () => {
          await rejects('UPDATE knowledge_documents SET content=$1 WHERE id=$2', ['overwrite', document.id]);
          await rejects("INSERT INTO knowledge_documents (document_key,version,title,content,content_hash,source_reference,topic) VALUES ($1,2,'fixture','fixture',$2,'source','GENERAL')", [fixture, hash('different')]);
          await rejects("INSERT INTO knowledge_documents (document_key,version,title,content,content_hash,source_reference,topic,status) SELECT document_key,2,title,content,content_hash,source_reference,topic,'ACTIVE' FROM knowledge_documents WHERE id=$1", [document.id], '23505');
          await rejects("UPDATE knowledge_chunks SET embedding='[1,2,3]'::public.vector,embedding_model='synthetic',embedding_dimensions=2,embedding_status='READY' WHERE id=$1", [chunk.id]);
          await tx.$executeRaw`UPDATE knowledge_chunks SET embedding='[1,2,3]'::public.vector,
            embedding_model='synthetic',embedding_dimensions=3,embedding_status='READY' WHERE id=${chunk.id}::uuid`;
          const vectors = await tx.$queryRaw<{ dimensions: number; distance: number }[]>`
            SELECT public.vector_dims(embedding) AS dimensions, embedding OPERATOR(public.<->) '[1,2,3]'::public.vector AS distance
            FROM knowledge_chunks WHERE id=${chunk.id}::uuid
          `;
          assert.equal(vectors[0]?.dimensions, 3);
          assert.equal(vectors[0]?.distance, 0);
        });
        await t.test('fertilizer composition and versioned calculator/rule configurations are constrained', async () => {
          await rejects('UPDATE fertilizers SET nitrogen_percent=101 WHERE id=$1', [fertilizer.id]);
          await rejects('UPDATE calculator_configs SET parameters=$1::jsonb WHERE id=$2', ['{"overwrite":true}', calculator.id]);
          await rejects("INSERT INTO calculator_configs (kind,config_key,version,parameters,unit,source_reference,status) SELECT kind,config_key,2,parameters,unit,source_reference,'ACTIVE' FROM calculator_configs WHERE id=$1", [calculator.id], '23505');
          await rejects('UPDATE fertilizer_rules SET version=2 WHERE id=$1', [fertilizer.rules[0]?.id]);
          await rejects("INSERT INTO fertilizer_rules (fertilizer_id,rule_key,version,parameters,unit,source_reference,status) SELECT fertilizer_id,rule_key,2,parameters,unit,source_reference,'ACTIVE' FROM fertilizer_rules WHERE id=$1", [fertilizer.rules[0]?.id], '23505');
        });
        await t.test('AI provenance, scan ownership, and immutable audit records are enforced', async () => {
          await rejects("INSERT INTO ai_queries (user_id,scan_id,question) VALUES ($1,$2,'fixture?')", [otherUser.id, scan.id]);
          await rejects("INSERT INTO ai_queries (user_id,scan_id,question) VALUES ($1,$2,'fixture?')", [user.id, anonymousScan.id]);
          await rejects("INSERT INTO ai_responses (query_id,status,answer,provider_model,processing_ms) VALUES ($1,'GROUNDED','fixture','synthetic',0)", [query.id]);
          await rejects('UPDATE ai_responses SET answer=$1 WHERE id=$2', ['overwrite', response.id]);
          await rejects('UPDATE audit_logs SET changes=$1::jsonb WHERE id=$2', ['{"overwrite":true}', audit.id]);
          await rejects('UPDATE ai_queries SET question=$1 WHERE id=$2', ['overwrite', query.id]);
        });
        await t.test('version creators cannot be reassigned or restored after removal', async () => {
          await rejects('UPDATE knowledge_documents SET created_by_id=$1 WHERE id=$2', [otherUser.id, document.id]);
          await rejects('UPDATE calculator_configs SET created_by_id=$1 WHERE id=$2', [otherUser.id, calculator.id]);
          await tx.knowledgeDocument.update({ where: { id: document.id }, data: { createdById: admin.id } });
          await tx.calculatorConfig.update({ where: { id: calculator.id }, data: { createdById: admin.id } });
          await tx.$executeRawUnsafe('SAVEPOINT removed_creator');
          try {
            await tx.calculatorConfig.update({ where: { id: calculator.id }, data: { createdById: null } });
            await rejects('UPDATE calculator_configs SET created_by_id=$1 WHERE id=$2', [admin.id, calculator.id]);
          } finally {
            await tx.$executeRawUnsafe('ROLLBACK TO SAVEPOINT removed_creator');
            await tx.$executeRawUnsafe('RELEASE SAVEPOINT removed_creator');
          }
        });
        await t.test('database-side timestamps and creator deletion policies work', async () => {
          const oldTimestamp = disease.updatedAt;
          await tx.$executeRaw`UPDATE diseases SET name='Updated synthetic fixture' WHERE id=${disease.id}::uuid`;
          const updated = await tx.disease.findUniqueOrThrow({ where: { id: disease.id } });
          assert.ok(updated.updatedAt > oldTimestamp);
          await tx.user.delete({ where: { id: admin.id } });
          assert.equal((await tx.auditLog.findUniqueOrThrow({ where: { id: audit.id } })).actorId, null);
          assert.equal((await tx.knowledgeDocument.findUniqueOrThrow({ where: { id: document.id } })).createdById, null);
          assert.equal((await tx.calculatorConfig.findUniqueOrThrow({ where: { id: calculator.id } })).createdById, null);
        });
        throw rollbackFixture;
      }, { maxWait: 10000, timeout: 170000 }), (error: unknown) => error === rollbackFixture);
      assert.ok(userId);
      assert.equal(await prisma.user.findUnique({ where: { id: userId } }), null, 'Synthetic fixtures must leave no durable records');
    } finally {
      await prisma.$disconnect();
    }
  });
