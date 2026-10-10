import { createHash, randomUUID } from 'node:crypto';
import type { Logger } from 'pino';
import { AppError } from '../../errors/app-error.js';
import type { AiInferenceClient } from '../inference/inference.types.js';
import type { ScanRepository } from './scan.repository.js';
import {
  inferenceFailureCodes,
  type ImageStorage,
  type ScanRecord,
  scanLimits,
  scanResponse,
  type ValidatedImage,
} from './scan.types.js';
import { validateImage } from './scan.validation.js';

const digest = (value: string | Buffer) => createHash('sha256').update(value).digest('hex');
export function createScanService(
  repository: ScanRepository,
  storage: ImageStorage,
  logger: Logger,
  inference?: AiInferenceClient,
) {
  async function deleteAsset(id: string, publicId: string) {
    await storage.destroy(publicId);
    await repository.finishCleanup(id);
  }
  async function analyze(scan: ScanRecord, image: ValidatedImage) {
    if (scan.status === 'COMPLETED') return scanResponse(scan);
    let attemptId: string | null;
    try {
      await repository.failInference(
        scan.id,
        'INFERENCE_INTERRUPTED',
        new Date(Date.now() - scanLimits.inferenceLeaseMs),
      );
      attemptId = await repository.startInference(scan.id);
      if (!attemptId) {
        const current = await repository.findScan(scan.id);
        if (!current) throw new Error('Saved scan is unavailable');
        return scanResponse(current);
      }
    } catch {
      throw new AppError('SCAN_PROCESSING_UNAVAILABLE');
    }
    let persisting = false;
    try {
      if (!inference?.enabled) throw new AppError('INFERENCE_UNAVAILABLE');
      const result = await inference.predict(image);
      persisting = true;
      return scanResponse(await repository.completeInference(scan.id, attemptId, result));
    } catch (error) {
      const code = persisting
        ? 'INFERENCE_PERSISTENCE_FAILED'
        : error instanceof AppError && inferenceFailureCodes.some((item) => item === error.code)
          ? error.code
          : 'INFERENCE_FAILED';
      try {
        // A lost persistence acknowledgement must not replace a committed outcome.
        const current = await repository.findScan(scan.id);
        if (current?.status === 'COMPLETED') return scanResponse(current);
        await repository.failInference(scan.id, code, undefined, attemptId);
        const failed = await repository.findScan(scan.id);
        if (!failed) throw new Error('Saved scan is unavailable');
        return scanResponse(failed);
      } catch {
        logger.error({ code: 'SCAN_RECOVERY_PENDING' }, 'Saved scan requires inference recovery');
        throw new AppError('SCAN_PROCESSING_UNAVAILABLE');
      }
    }
  }
  return {
    enabled: storage.enabled,
    async create(file: Express.Multer.File | undefined, key: string, userId: string | null) {
      if (!storage.enabled) throw new AppError('UPLOAD_UNAVAILABLE');
      const image = await validateImage(file);
      const imageHash = digest(image.bytes);
      const { record, claimed } = await repository.claim(
        digest(`${userId ?? 'anonymous'}:${key}`),
        imageHash,
        randomUUID(),
      );
      if (record.imageHash !== imageHash) throw new AppError('CONFLICT');
      if (record.state === 'COMPLETED' && record.scan)
        return { scan: await analyze(record.scan, image), replayed: true };
      if (!claimed) throw new AppError('UPLOAD_IN_PROGRESS');
      let accepted = false;
      let saved: ScanRecord | undefined;
      let replayed = false;
      try {
        const stored = await storage.upload(image, record.publicId);
        accepted = true;
        const completed = await repository.complete(record.id, { userId, image, stored });
        if (!completed.scan) throw new Error('Scan was not committed');
        saved = completed.scan;
      } catch {
        try {
          // A lost database commit acknowledgement must never delete a saved scan.
          const current = await repository.find(record.id);
          if (current?.state === 'COMPLETED' && current.scan) {
            saved = current.scan;
            replayed = true;
          } else if (await repository.scheduleCleanup(record.id, accepted)) {
            // Unknown provider outcomes wait for the stale-upload grace period.
            if (accepted) await deleteAsset(record.id, record.publicId);
          }
        } catch {
          logger.error({ code: 'SCAN_CLEANUP_PENDING' }, 'Upload recovery requires cleanup retry');
        }
        if (!replayed) throw new AppError('UPLOAD_FAILED');
      }
      // Inference failure never enters upload compensation or deletes a saved asset.
      if (!saved) throw new AppError('UPLOAD_FAILED');
      return { scan: await analyze(saved, image), replayed };
    },
    async read(id: string, userId: string | null, key?: string) {
      if (userId === null && !key) throw new AppError('AUTHENTICATION_ERROR');
      const scan = await repository.read(id, userId, key ? digest(`anonymous:${key}`) : undefined);
      if (!scan) throw new AppError('NOT_FOUND');
      if (
        ['PENDING', 'PROCESSING'].includes(scan.status) &&
        scan.updatedAt.getTime() < Date.now() - scanLimits.inferenceLeaseMs
      ) {
        await repository.failInference(
          scan.id,
          'INFERENCE_INTERRUPTED',
          new Date(Date.now() - scanLimits.inferenceLeaseMs),
        );
        const current = await repository.findScan(scan.id);
        if (!current) throw new AppError('NOT_FOUND');
        return scanResponse(current);
      }
      return scanResponse(scan);
    },
    recoverStale(now = new Date()) {
      return repository.failStaleInference(new Date(now.getTime() - scanLimits.inferenceLeaseMs));
    },
    async cleanup(now = new Date()) {
      if (!storage.enabled) throw new AppError('UPLOAD_UNAVAILABLE');
      const before = new Date(now.getTime() - scanLimits.cleanupDelayMs);
      let removed = 0;
      let failed = 0;
      for (const record of await repository.cleanupCandidates(before)) {
        if (!(await repository.claimCleanup(record.id, before))) continue;
        try {
          await deleteAsset(record.id, record.publicId);
          removed++;
        } catch {
          failed++;
          logger.error(
            { code: 'SCAN_CLEANUP_PENDING' },
            'Upload cleanup will need another attempt',
          );
        }
      }
      // Keep failed-attempt digests for a day to allow a safe same-key retry;
      // successful scans and their idempotency records are never pruned here.
      const pruned = await repository.pruneFailed(new Date(now.getTime() - 24 * 60 * 60_000));
      return { removed, failed, pruned };
    },
  };
}
export type ScanService = ReturnType<typeof createScanService>;
