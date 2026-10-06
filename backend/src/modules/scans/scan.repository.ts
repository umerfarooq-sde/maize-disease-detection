import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import type { ScanInput, UploadRecord } from './scan.types.js';

export interface ScanRepository {
  claim(
    keyHash: string,
    imageHash: string,
    id: string,
  ): Promise<{ record: UploadRecord; claimed: boolean }>;
  find(id: string): Promise<UploadRecord | null>;
  complete(id: string, input: ScanInput): Promise<UploadRecord>;
  scheduleCleanup(id: string, immediate: boolean): Promise<boolean>;
  cleanupCandidates(before: Date): Promise<UploadRecord[]>;
  claimCleanup(id: string, before: Date): Promise<boolean>;
  finishCleanup(id: string): Promise<void>;
  pruneFailed(before: Date): Promise<number>;
}

export function createScanRepository(database: PrismaClient): ScanRepository {
  const include = { scan: true } as const;
  return {
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
