import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type {
  AiInferenceClient,
  InferencePrediction,
} from '../../src/modules/inference/inference.types.js';
import type { ScanRepository } from '../../src/modules/scans/scan.repository.js';
import type {
  ImageStorage,
  ScanRecord,
  UploadRecord,
  ValidatedImage,
} from '../../src/modules/scans/scan.types.js';

export function fakeInference(overrides: Partial<InferencePrediction> = {}) {
  const calls: ValidatedImage[] = [];
  const result: InferencePrediction = {
    predictedClass: 'Common_Rust',
    confidence: 0.8,
    topProbabilities: [
      { className: 'Common_Rust', probability: 0.8 },
      { className: 'Gray_Leaf_Spot', probability: 0.1 },
      { className: 'Healthy', probability: 0.05 },
      { className: 'Northern_Corn_Leaf_Blight', probability: 0.05 },
    ],
    modelVersion: 'fixture-model-v1',
    preprocessingVersion: '1.0.0',
    inferenceDurationMs: 12.5,
    predictionStatus: 'LOW_CONFIDENCE',
    uncertaintyReason: 'THRESHOLD_UNCONFIGURED',
    confidenceThreshold: null,
    ...overrides,
  };
  const client: AiInferenceClient = {
    enabled: true,
    async predict(image) {
      calls.push(image);
      return result;
    },
  };
  return { client, calls, result };
}

export async function imageFile(
  format: 'png' | 'jpeg' | 'webp' = 'png',
  orientation?: number,
): Promise<Express.Multer.File> {
  let encoder = sharp({
    create: { width: 24, height: orientation ? 48 : 24, channels: 3, background: '#245443' },
  });
  if (orientation) encoder = encoder.withMetadata({ orientation });
  const buffer = await encoder.toFormat(format).toBuffer();
  return {
    fieldname: 'image',
    originalname: `leaf.${format}`,
    mimetype: `image/${format}`,
    buffer,
    size: buffer.length,
    encoding: '7bit',
    destination: '',
    filename: '',
    path: '',
    stream: sharp(buffer),
  };
}
export function fakeStorage() {
  const assets = new Set<string>();
  const storage: ImageStorage = {
    enabled: true,
    async upload(_image, publicId) {
      assets.add(publicId);
      return {
        publicId,
        url: `https://res.cloudinary.com/test/image/authenticated/${publicId}.png`,
        uploadedAt: new Date(),
      };
    },
    async destroy(publicId) {
      assets.delete(publicId);
    },
  };
  return { storage, assets };
}
export function memoryScans() {
  const records = new Map<string, UploadRecord>();
  const findScan = (id: string) =>
    [...records.values()].find((record) => record.scan?.id === id)?.scan ?? null;
  const repository: ScanRepository = {
    async findScan(id) {
      return findScan(id);
    },
    async read(id, userId, keyHash) {
      const record = [...records.values()].find((item) => item.scan?.id === id);
      return record?.scan?.userId === userId &&
        (userId !== null || record?.requestKeyHash === keyHash)
        ? (record?.scan ?? null)
        : null;
    },
    async history(userId, limit, cursor) {
      const owned = [...records.values()]
        .flatMap((record) => (record.scan?.userId === userId ? [record.scan] : []))
        .sort(
          (left, right) =>
            right.createdAt.getTime() - left.createdAt.getTime() || right.id.localeCompare(left.id),
        );
      const offset = cursor ? owned.findIndex((scan) => scan.id === cursor) + 1 : 0;
      if (cursor && offset === 0) return null;
      const rows = owned.slice(offset, offset + limit + 1);
      const items = rows.slice(0, limit);
      return { items, nextCursor: rows.length > limit ? (items.at(-1)?.id ?? null) : null };
    },
    async startInference(id) {
      const scan = findScan(id);
      if (!scan || !['PENDING', 'FAILED'].includes(scan.status) || scan.predictions.length)
        return null;
      const attemptId = randomUUID();
      Object.assign(scan, {
        status: 'PROCESSING',
        inferenceAttemptId: attemptId,
        errorCode: null,
        finishedAt: null,
        processingTimeMs: null,
        updatedAt: new Date(),
      });
      return attemptId;
    },
    async completeInference(id, attemptId, result) {
      const scan = findScan(id);
      if (scan?.status !== 'PROCESSING' || scan.inferenceAttemptId !== attemptId)
        throw new Error('Expired inference attempt');
      const now = new Date();
      scan.predictions.push({
        id: randomUUID(),
        scanId: id,
        modelVersionId: randomUUID(),
        diseaseId: null,
        predictedClass: result.predictedClass,
        confidence: result.confidence,
        probabilities: Object.fromEntries(
          result.topProbabilities.map((item) => [item.className, item.probability]),
        ),
        predictionStatus: result.predictionStatus,
        uncertaintyReason: result.uncertaintyReason,
        confidenceThreshold: result.confidenceThreshold,
        inferenceDurationMs: result.inferenceDurationMs,
        inferredAt: now,
        createdAt: now,
        modelVersion: {
          version: result.modelVersion,
          preprocessingVersion: result.preprocessingVersion,
        },
      });
      Object.assign(scan, {
        status: 'COMPLETED',
        inferenceAttemptId: null,
        errorCode: null,
        finishedAt: now,
        processingTimeMs: Math.ceil(result.inferenceDurationMs),
        updatedAt: now,
      });
      return scan;
    },
    async failInference(id, code, before, attemptId) {
      const scan = findScan(id);
      if (
        !scan ||
        !['PENDING', 'PROCESSING'].includes(scan.status) ||
        (before && scan.updatedAt >= before) ||
        (attemptId && scan.inferenceAttemptId !== attemptId)
      )
        return;
      Object.assign(scan, {
        status: 'FAILED',
        inferenceAttemptId: null,
        errorCode: code,
        finishedAt: new Date(),
        updatedAt: new Date(),
      });
    },
    async failStaleInference(before) {
      let count = 0;
      for (const record of records.values()) {
        if (
          record.state === 'COMPLETED' &&
          record.scan &&
          ['PENDING', 'PROCESSING'].includes(record.scan.status) &&
          record.scan.updatedAt < before
        ) {
          await repository.failInference(record.scan.id, 'INFERENCE_INTERRUPTED', before);
          count++;
        }
      }
      return count;
    },
    async claim(requestKeyHash, imageHash, id) {
      const existing = [...records.values()].find((r) => r.requestKeyHash === requestKeyHash);
      if (existing) {
        const claimed = existing.state === 'FAILED' && existing.imageHash === imageHash;
        if (claimed) existing.state = 'UPLOADING';
        return { record: existing, claimed };
      }
      const record: UploadRecord = {
        id,
        requestKeyHash,
        imageHash,
        publicId: `maizedoctor/scans/${id}`,
        state: 'UPLOADING',
        scanId: null,
        scan: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      records.set(id, record);
      return { record, claimed: true };
    },
    async find(id) {
      return records.get(id) ?? null;
    },
    async complete(id, input) {
      const record = records.get(id);
      if (record?.state !== 'UPLOADING') throw new Error('No active upload');
      const scan: ScanRecord = {
        id: randomUUID(),
        userId: input.userId,
        imageUrl: input.stored.url,
        cloudinaryPublicId: input.stored.publicId,
        imageMimeType: input.image.mimeType,
        imageBytes: input.image.bytes.length,
        uploadedAt: input.stored.uploadedAt,
        status: 'PENDING',
        processingTimeMs: null,
        inferenceAttemptId: null,
        predictions: [],
        errorCode: null,
        finishedAt: null,
        expiresAt: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      record.scan = scan;
      record.scanId = scan.id;
      record.state = 'COMPLETED';
      return record;
    },
    async scheduleCleanup(id, immediate) {
      const record = records.get(id);
      if (record?.state !== 'UPLOADING') return false;
      record.state = immediate ? 'CLEANING' : 'CLEANUP_PENDING';
      record.updatedAt = new Date();
      return true;
    },
    async cleanupCandidates(before) {
      return [...records.values()].filter(
        (r) =>
          ['UPLOADING', 'CLEANUP_PENDING', 'CLEANING'].includes(r.state) &&
          !r.scanId &&
          r.updatedAt < before,
      );
    },
    async claimCleanup(id, before) {
      const record = records.get(id);
      if (
        !record ||
        record.updatedAt >= before ||
        record.scanId ||
        !['UPLOADING', 'CLEANUP_PENDING', 'CLEANING'].includes(record.state)
      )
        return false;
      record.state = 'CLEANING';
      record.updatedAt = new Date();
      return true;
    },
    async finishCleanup(id) {
      const record = records.get(id);
      if (record?.state === 'CLEANING') record.state = 'FAILED';
    },
    async pruneFailed(before) {
      let count = 0;
      for (const [id, record] of records)
        if (record.state === 'FAILED' && !record.scanId && record.updatedAt < before) {
          records.delete(id);
          count++;
        }
      return count;
    },
  };
  return { repository, records };
}
