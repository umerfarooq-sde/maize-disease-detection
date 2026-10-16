import { randomUUID } from 'node:crypto';
import { AppError } from '../../errors/app-error.js';
import type { ImageStorage, ValidatedImage } from '../scans/scan.types.js';
import { profileResponse } from './profile.types.js';
import type { ProfileMediaRepository } from './profile-media.repository.js';

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
        if (id === current[0]?.avatarPublicId || id === current[0]?.avatarPendingPublicId) {
          failed++;
          continue;
        }
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
    async imageLocation(userId: string) {
      const row = await repository.read(userId);
      if (!row?.avatarUrl || !row.avatarPublicId) throw new AppError('NOT_FOUND');
      return { url: row.avatarUrl, publicId: row.avatarPublicId, purpose: 'profiles' as const };
    },
    cleanup,
    async upload(userId: string, revision: string, image: ValidatedImage) {
      if (!storage.enabled) throw new AppError('UPLOAD_UNAVAILABLE');
      const publicId = `maizedoctor/profiles/${randomUUID()}`;
      await repository.reserve(userId, revision, publicId);
      let uploaded = false;
      try {
        const stored = await storage.upload(image, publicId);
        if (stored.publicId !== publicId) throw new AppError('UPLOAD_FAILED');
        uploaded = true;
        await repository.finish(userId, publicId, stored);
      } catch (error) {
        // Provider timeouts are ambiguous: retain intent until stale recovery so a
        // delayed upload cannot complete after immediate deletion compensation.
        if (!uploaded) throw error;
        let committed: boolean;
        try {
          // Serialize with finish before retiring this exact attempt. A committed
          // photo survives a lost acknowledgement; uncertain DB outcomes never
          // authorize cloud deletion. Retired attempts cannot finalize later.
          await repository.retirePending(userId, new Date(), publicId);
          const current = await repository.read(userId);
          committed = current?.avatarPublicId === publicId;
        } catch {
          throw error;
        }
        if (!committed) {
          // Recovery is durable. Provider deletion must never hold the mutation
          // response open or delete an asset whose commit outcome is uncertain.
          throw error;
        }
      }
      // finish atomically queued the previous asset. The bounded cleanup CLI
      // owns provider work; no untracked background promise is started here.
      return profileResponse(await repository.read(userId));
    },
    async remove(userId: string, revision: string) {
      try {
        await repository.remove(userId, revision);
      } catch (error) {
        // A lost commit acknowledgement is not proof of failure. A reread
        // observes the serialized state; never retry deletion automatically.
        const current = await repository.read(userId);
        if (!current || current.avatarPublicId || current.avatarPendingPublicId) throw error;
        return profileResponse(current);
      }
      return profileResponse(await repository.read(userId));
    },
  };
}
export type ProfileMediaService = ReturnType<typeof createProfileMediaService>;
