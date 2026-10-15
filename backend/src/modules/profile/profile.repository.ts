import { AppError } from '../../errors/app-error.js';
import type { FarmerProfile, PrismaClient } from '../../generated/prisma/client.js';
import { type ProfilePatch, profileResponse } from './profile.types.js';

export interface ProfileRepository {
  read(userId: string): Promise<FarmerProfile | null>;
  patch(userId: string, input: ProfilePatch): Promise<FarmerProfile>;
}
export function createProfileRepository(database: PrismaClient): ProfileRepository {
  return {
    read(userId) {
      return database.farmerProfile.findFirst({
        where: { userId, user: { role: 'FARMER', status: 'ACTIVE' } },
      });
    },
    patch(userId, input) {
      return database.$transaction(
        async (tx) => {
          const owners = await tx.$queryRaw<
            { id: string }[]
          >`SELECT id FROM users WHERE id=${userId}::uuid AND role='FARMER' AND status='ACTIVE' FOR UPDATE`;
          if (!owners.length) throw new AppError('AUTHENTICATION_ERROR');
          const current = await tx.farmerProfile.findUnique({ where: { userId } });
          if ((profileResponse(current).profile?.revision ?? null) !== input.expectedRevision)
            throw new AppError('CONFLICT');
          const changes = {
            ...(input.displayName !== undefined ? { displayName: input.displayName } : {}),
            ...(input.region !== undefined ? { region: input.region } : {}),
            ...(input.countryCode !== undefined ? { countryCode: input.countryCode } : {}),
            ...(input.fieldAreaHectares !== undefined
              ? { fieldAreaHectares: input.fieldAreaHectares }
              : {}),
          };
          if (!current) {
            if (!changes.displayName) throw new AppError('VALIDATION_ERROR');
            return tx.farmerProfile.create({
              data: { userId, ...changes, displayName: changes.displayName },
            });
          }
          return tx.farmerProfile.update({
            where: { userId },
            data: {
              ...changes,
              updatedAt: new Date(Math.max(Date.now(), current.updatedAt.getTime() + 1)),
            },
          });
        },
        { maxWait: 10000, timeout: 15000 },
      );
    },
  };
}
