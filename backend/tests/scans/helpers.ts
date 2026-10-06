import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type { Scan } from '../../src/generated/prisma/client.js';
import type { ScanRepository } from '../../src/modules/scans/scan.repository.js';
import type { ImageStorage, UploadRecord } from '../../src/modules/scans/scan.types.js';

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
  const repository: ScanRepository = {
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
      const scan: Scan = {
        id: randomUUID(),
        userId: input.userId,
        imageUrl: input.stored.url,
        cloudinaryPublicId: input.stored.publicId,
        imageMimeType: input.image.mimeType,
        imageBytes: input.image.bytes.length,
        uploadedAt: input.stored.uploadedAt,
        status: 'PENDING',
        processingTimeMs: null,
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
