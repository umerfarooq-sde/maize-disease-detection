import { createHash, randomUUID } from 'node:crypto';
import type { Logger } from 'pino';
import { AppError } from '../../errors/app-error.js';
import type { ScanRepository } from './scan.repository.js';
import { type ImageStorage, scanLimits, scanResponse } from './scan.types.js';
import { validateImage } from './scan.validation.js';

const digest = (value: string | Buffer) => createHash('sha256').update(value).digest('hex');
export function createScanService(
  repository: ScanRepository,
  storage: ImageStorage,
  logger: Logger,
) {
  async function deleteAsset(id: string, publicId: string) {
    await storage.destroy(publicId);
    await repository.finishCleanup(id);
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
        return { scan: scanResponse(record.scan), replayed: true };
      if (!claimed) throw new AppError('UPLOAD_IN_PROGRESS');
      let accepted = false;
      try {
        const stored = await storage.upload(image, record.publicId);
        accepted = true;
        const completed = await repository.complete(record.id, { userId, image, stored });
        if (!completed.scan) throw new Error('Scan was not committed');
        return { scan: scanResponse(completed.scan), replayed: false };
      } catch {
        try {
          // A lost database commit acknowledgement must never delete a saved scan.
          const current = await repository.find(record.id);
          if (current?.state === 'COMPLETED' && current.scan)
            return { scan: scanResponse(current.scan), replayed: true };
          if (await repository.scheduleCleanup(record.id, accepted)) {
            // Unknown provider outcomes wait for the stale-upload grace period.
            if (accepted) await deleteAsset(record.id, record.publicId);
          }
        } catch {
          logger.error({ code: 'SCAN_CLEANUP_PENDING' }, 'Upload recovery requires cleanup retry');
        }
        throw new AppError('UPLOAD_FAILED');
      }
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
