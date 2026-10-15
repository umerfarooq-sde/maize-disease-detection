import { AppError } from '../../errors/app-error.js';
import type { FarmerProfile, Prisma, PrismaClient } from '../../generated/prisma/client.js';
import type { StoredImage } from '../scans/scan.types.js';
import { profileResponse } from './profile.types.js';

export interface ProfileMediaRepository {
  read(userId: string): Promise<FarmerProfile | null>;
  reserve(userId: string, revision: string, publicId: string): Promise<void>;
  finish(userId: string, publicId: string, stored: StoredImage): Promise<void>;
  remove(userId: string, revision: string): Promise<void>;
  candidates(userId?: string): Promise<FarmerProfile[]>;
  retirePending(userId: string, cutoff: Date, publicId?: string): Promise<void>;
  cleared(userId: string, publicId: string): Promise<void>;
}
export function createProfileMediaRepository(database: PrismaClient): ProfileMediaRepository {
  async function locked<T>(
    userId: string,
    active: boolean,
    action: (tx: Prisma.TransactionClient, row: FarmerProfile) => Promise<T>,
  ) {
    return database.$transaction(
      async (tx) => {
        const owners = await tx.$queryRaw<
          { status: string }[]
        >`SELECT status::text FROM users WHERE id=${userId}::uuid AND role='FARMER' FOR UPDATE`;
        if (!owners[0] || (active && owners[0].status !== 'ACTIVE'))
          throw new AppError('AUTHENTICATION_ERROR');
        const row = await tx.farmerProfile.findUnique({ where: { userId } });
        if (!row) throw new AppError('NOT_FOUND');
        return action(tx, row);
      },
      { maxWait: 10000, timeout: 15000 },
    );
  }
  return {
    read(userId) {
      return database.farmerProfile.findFirst({
        where: { userId, user: { status: 'ACTIVE', role: 'FARMER' } },
      });
    },
    reserve(userId, revision, publicId) {
      return locked(userId, true, async (tx, row) => {
        if (row.avatarPendingPublicId) throw new AppError('UPLOAD_IN_PROGRESS');
        if (
          row.avatarCleanupPublicIds.length >= 8 ||
          profileResponse(row).profile?.revision !== revision
        )
          throw new AppError('CONFLICT');
        await tx.farmerProfile.update({
          where: { userId },
          data: { avatarPendingPublicId: publicId, avatarUploadStartedAt: new Date() },
        });
      });
    },
    finish(userId, publicId, stored) {
      return locked(userId, true, async (tx, row) => {
        if (row.avatarPendingPublicId !== publicId) throw new AppError('CONFLICT');
        await tx.farmerProfile.update({
          where: { userId },
          data: {
            avatarPublicId: stored.publicId,
            avatarUrl: stored.url,
            avatarPendingPublicId: null,
            avatarUploadStartedAt: null,
            avatarCleanupPublicIds: row.avatarPublicId
              ? [...row.avatarCleanupPublicIds, row.avatarPublicId]
              : row.avatarCleanupPublicIds,
          },
        });
      });
    },
    remove(userId, revision) {
      return locked(userId, true, async (tx, row) => {
        if (
          row.avatarPendingPublicId ||
          row.avatarCleanupPublicIds.length >= 8 ||
          profileResponse(row).profile?.revision !== revision
        )
          throw new AppError('CONFLICT');
        await tx.farmerProfile.update({
          where: { userId },
          data: {
            avatarPublicId: null,
            avatarUrl: null,
            avatarCleanupPublicIds: row.avatarPublicId
              ? [...row.avatarCleanupPublicIds, row.avatarPublicId]
              : row.avatarCleanupPublicIds,
          },
        });
      });
    },
    candidates(userId) {
      return database.farmerProfile.findMany({
        where: {
          ...(userId ? { userId } : {}),
          OR: [
            { avatarPendingPublicId: { not: null } },
            { avatarCleanupPublicIds: { isEmpty: false } },
          ],
        },
        orderBy: { updatedAt: 'asc' },
        take: 10,
      });
    },
    retirePending(userId, cutoff, publicId) {
      return locked(userId, false, async (tx, row) => {
        if (
          !row.avatarPendingPublicId ||
          !row.avatarUploadStartedAt ||
          (publicId
            ? row.avatarPendingPublicId !== publicId
            : row.avatarUploadStartedAt > cutoff) ||
          row.avatarCleanupPublicIds.length >= 8
        )
          return;
        await tx.farmerProfile.update({
          where: { userId },
          data: {
            avatarCleanupPublicIds: [...row.avatarCleanupPublicIds, row.avatarPendingPublicId],
            avatarPendingPublicId: null,
            avatarUploadStartedAt: null,
          },
        });
      });
    },
    cleared(userId, publicId) {
      return locked(userId, false, async (tx, row) => {
        await tx.farmerProfile.update({
          where: { userId },
          data: {
            avatarCleanupPublicIds: row.avatarCleanupPublicIds.filter((id) => id !== publicId),
            ...(row.avatarPendingPublicId === publicId
              ? { avatarPendingPublicId: null, avatarUploadStartedAt: null }
              : {}),
          },
        });
      });
    },
  };
}
