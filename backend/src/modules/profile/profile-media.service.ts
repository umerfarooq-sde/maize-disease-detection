import { randomUUID } from 'node:crypto';
import { AppError } from '../../errors/app-error.js';
import type { ImageStorage, ValidatedImage } from '../scans/scan.types.js';
import type { ProfileMediaRepository } from './profile-media.repository.js';
import { profileResponse } from './profile.types.js';

export function createProfileMediaService(
  repository: ProfileMediaRepository,
  storage: ImageStorage,
) {
  async function cleanup(userId?: string) {
    let removed = 0,
      failed = 0;
    const cutoff = new Date(Date.now() - 2 * 60_000);
    for (const row of await repository.candidates(userId)) {
      await repository.retirePending(row.userId, cutoff);
      const current = await repository.candidates(row.userId);
      for (const id of current[0]?.avatarCleanupPublicIds ?? []) {
        if (removed + failed >= 20) return { removed, failed };
        try {
          await storage.destroy(id);
          await repository.cleared(row.userId, id);
          removed++;
        } catch {
          failed++;
        }
      }
    }
    return { removed, failed };
  }
  return {
    enabled: storage.enabled,
    cleanup,
    async upload(userId: string, revision: string, image: ValidatedImage) {
      if (!storage.enabled) throw new AppError('UPLOAD_UNAVAILABLE');
      const publicId = `maizedoctor/profiles/${randomUUID()}`;
      await repository.reserve(userId, revision, publicId);
      try {
        const stored = await storage.upload(image, publicId);
        if (stored.publicId !== publicId) throw new AppError('UPLOAD_FAILED');
        await repository.finish(userId, publicId, stored);
      } catch (error) {
        // Intent was committed before upload; a failed compensation remains recoverable.
        try {
          await storage.destroy(publicId);
          await repository.cleared(userId, publicId);
        } catch {
          /* durable intent retained */
        }
        throw error;
      }
      try {
        await cleanup(userId);
      } catch {
        /* safe retry through the cleanup CLI */
      }
      return profileResponse(await repository.read(userId));
    },
    async remove(userId: string, revision: string) {
      await repository.remove(userId, revision);
      try {
        await cleanup(userId);
      } catch {
        /* durable old-asset intent retained */
      }
      return profileResponse(await repository.read(userId));
    },
  };
}
export type ProfileMediaService = ReturnType<typeof createProfileMediaService>;
