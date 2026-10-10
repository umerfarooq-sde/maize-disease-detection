import { randomUUID } from 'node:crypto';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import {
  diseaseLabels,
  type InferencePrediction,
  predictionSchema,
} from '../inference/inference.types.js';
import type { ScanInput, ScanRecord, UploadRecord } from './scan.types.js';

export interface ScanRepository {
  claim(
    keyHash: string,
    imageHash: string,
    id: string,
  ): Promise<{ record: UploadRecord; claimed: boolean }>;
  find(id: string): Promise<UploadRecord | null>;
  complete(id: string, input: ScanInput): Promise<UploadRecord>;
  findScan(id: string): Promise<ScanRecord | null>;
  read(id: string, userId: string | null, keyHash?: string): Promise<ScanRecord | null>;
  startInference(id: string): Promise<string | null>;
  completeInference(
    id: string,
    attemptId: string,
    prediction: InferencePrediction,
  ): Promise<ScanRecord>;
  failInference(id: string, code: string, before?: Date, attemptId?: string): Promise<void>;
  failStaleInference(before: Date): Promise<number>;
  scheduleCleanup(id: string, immediate: boolean): Promise<boolean>;
  cleanupCandidates(before: Date): Promise<UploadRecord[]>;
  claimCleanup(id: string, before: Date): Promise<boolean>;
  finishCleanup(id: string): Promise<void>;
  pruneFailed(before: Date): Promise<number>;
}

export function createScanRepository(database: PrismaClient): ScanRepository {
  const scanInclude = {
    predictions: {
      orderBy: { createdAt: 'desc' },
      take: 1,
      include: { modelVersion: { select: { version: true, preprocessingVersion: true } } },
    },
  } as const;
  const include = { scan: { include: scanInclude } } as const;
  return {
    findScan(id) {
      return database.scan.findUnique({ where: { id }, include: scanInclude });
    },
    read(id, userId, keyHash) {
      if (userId === null && !keyHash) return Promise.resolve(null);
      return database.scan.findFirst({
        where: {
          id,
          userId,
          ...(userId === null && keyHash ? { upload: { requestKeyHash: keyHash } } : {}),
        },
        include: scanInclude,
      });
    },
    async startInference(id) {
      const attemptId = randomUUID();
      const result = await database.scan.updateMany({
        where: { id, status: { in: ['PENDING', 'FAILED'] }, predictions: { none: {} } },
        data: {
          status: 'PROCESSING',
          inferenceAttemptId: attemptId,
          finishedAt: null,
          errorCode: null,
          processingTimeMs: null,
        },
      });
      return result.count === 1 ? attemptId : null;
    },
    completeInference(id, attemptId, input) {
      const prediction = predictionSchema.parse(input);
      return database.$transaction(
        async (tx) => {
          const claimed = await tx.scan.updateMany({
            where: { id, status: 'PROCESSING', inferenceAttemptId: attemptId },
            data: { updatedAt: new Date() },
          });
          if (claimed.count !== 1) throw new Error('Inference lease is no longer active');
          const model = await tx.modelVersion.findUnique({
            where: { version: prediction.modelVersion },
          });
          if (
            !model ||
            !['VALIDATED', 'PRODUCTION'].includes(model.status) ||
            model.preprocessingVersion !== prediction.preprocessingVersion ||
            model.classLabels.length !== diseaseLabels.length ||
            model.classLabels.some((label, index) => label !== diseaseLabels[index])
          )
            throw new Error('The classifier version is not registered for inference');
          const scan = await tx.scan.findUniqueOrThrow({ where: { id } });
          // Prisma truncates PostgreSQL microseconds; round up when its clock leads.
          const inferredAt = new Date(Math.max(Date.now(), scan.createdAt.getTime() + 1));
          const probabilities = Object.fromEntries(
            prediction.topProbabilities.map((item) => [item.className, item.probability]),
          );
          await tx.scanPrediction.create({
            data: {
              scanId: id,
              modelVersionId: model.id,
              predictedClass: prediction.predictedClass,
              confidence: prediction.confidence,
              probabilities,
              predictionStatus: prediction.predictionStatus,
              uncertaintyReason: prediction.uncertaintyReason,
              confidenceThreshold: prediction.confidenceThreshold,
              inferenceDurationMs: prediction.inferenceDurationMs,
              inferredAt,
            },
          });
          return tx.scan.update({
            where: { id },
            data: {
              status: 'COMPLETED',
              inferenceAttemptId: null,
              errorCode: null,
              finishedAt: inferredAt,
              processingTimeMs: Math.ceil(prediction.inferenceDurationMs),
            },
            include: scanInclude,
          });
        },
        { maxWait: 10_000, timeout: 15_000 },
      );
    },
    async failInference(id, code, before, attemptId) {
      // Use database time: a workstation clock behind PostgreSQL must not violate
      // the existing finished_at >= created_at invariant during failure recovery.
      await database.$executeRaw(Prisma.sql`
        UPDATE scans SET status='FAILED', inference_attempt_id=NULL, error_code=${code},
          finished_at=GREATEST(clock_timestamp(), created_at)
        WHERE id=${id}::uuid AND status IN ('PENDING','PROCESSING')
          ${before ? Prisma.sql`AND updated_at < ${before}` : Prisma.empty}
          ${attemptId ? Prisma.sql`AND inference_attempt_id=${attemptId}::uuid` : Prisma.empty}
      `);
    },
    async failStaleInference(before) {
      return database.$executeRaw`
        UPDATE scans SET status='FAILED', inference_attempt_id=NULL,
          error_code='INFERENCE_INTERRUPTED', finished_at=GREATEST(clock_timestamp(), created_at)
        WHERE id IN (
          SELECT s.id FROM scans s JOIN scan_uploads u ON u.scan_id=s.id
          WHERE s.status IN ('PENDING','PROCESSING') AND s.updated_at < ${before}
            AND u.state='COMPLETED'
          ORDER BY s.updated_at LIMIT 100 FOR UPDATE OF s SKIP LOCKED
        ) AND status IN ('PENDING','PROCESSING') AND updated_at < ${before}
      `;
    },
    async claim(requestKeyHash, imageHash, id) {
      try {
        const record = await database.scanUpload.create({
          data: { id, requestKeyHash, imageHash, publicId: `maizedoctor/scans/${id}` },
          include,
        });
        return { record, claimed: true };
      } catch (error) {
        if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== 'P2002')
          throw error;
      }
      let record = await database.scanUpload.findUniqueOrThrow({
        where: { requestKeyHash },
        include,
      });
      let claimed = false;
      if (record.state === 'FAILED' && record.imageHash === imageHash) {
        const updated = await database.scanUpload.updateMany({
          where: { id: record.id, state: 'FAILED' },
          data: { state: 'UPLOADING' },
        });
        claimed = updated.count === 1;
        record = await database.scanUpload.findUniqueOrThrow({ where: { id: record.id }, include });
      }
      return { record, claimed };
    },
    find(id) {
      return database.scanUpload.findUnique({ where: { id }, include });
    },
    complete(id, input) {
      return database.$transaction(
        async (tx) => {
          // Lock/conditional write prevents stale cleanup and upload completion racing.
          const locked = await tx.scanUpload.updateMany({
            where: { id, state: 'UPLOADING', scanId: null, publicId: input.stored.publicId },
            data: { updatedAt: new Date() },
          });
          if (locked.count !== 1) throw new Error('Upload is no longer active');
          const scan = await tx.scan.create({
            data: {
              userId: input.userId,
              imageUrl: input.stored.url,
              cloudinaryPublicId: input.stored.publicId,
              imageMimeType: input.image.mimeType,
              imageBytes: input.image.bytes.length,
              uploadedAt: input.stored.uploadedAt,
              status: 'PENDING',
            },
          });
          return tx.scanUpload.update({
            where: { id },
            data: { state: 'COMPLETED', scanId: scan.id },
            include,
          });
        },
        { maxWait: 10_000, timeout: 15_000 },
      );
    },
    async scheduleCleanup(id, immediate) {
      const result = await database.scanUpload.updateMany({
        where: { id, state: 'UPLOADING', scanId: null },
        data: { state: immediate ? 'CLEANING' : 'CLEANUP_PENDING' },
      });
      return result.count === 1;
    },
    cleanupCandidates(before) {
      return database.scanUpload.findMany({
        where: {
          state: { in: ['UPLOADING', 'CLEANUP_PENDING', 'CLEANING'] },
          scanId: null,
          updatedAt: { lt: before },
        },
        orderBy: { updatedAt: 'asc' },
        take: 100,
        include,
      });
    },
    async claimCleanup(id, before) {
      const result = await database.scanUpload.updateMany({
        where: {
          id,
          state: { in: ['UPLOADING', 'CLEANUP_PENDING', 'CLEANING'] },
          scanId: null,
          updatedAt: { lt: before },
        },
        data: { state: 'CLEANING' },
      });
      return result.count === 1;
    },
    async finishCleanup(id) {
      await database.scanUpload.updateMany({
        where: { id, state: 'CLEANING', scanId: null },
        data: { state: 'FAILED' },
      });
    },
    async pruneFailed(before) {
      const rows = await database.scanUpload.findMany({
        where: { state: 'FAILED', scanId: null, updatedAt: { lt: before } },
        select: { id: true },
        take: 100,
      });
      // Recheck predicates so a retry that acquired the row cannot be removed.
      const result = await database.scanUpload.deleteMany({
        where: {
          id: { in: rows.map((row) => row.id) },
          state: 'FAILED',
          scanId: null,
          updatedAt: { lt: before },
        },
      });
      return result.count;
    },
  };
}
