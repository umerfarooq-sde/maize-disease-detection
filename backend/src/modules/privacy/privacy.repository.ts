import { AppError } from '../../errors/app-error.js';
import type { PrismaClient } from '../../generated/prisma/client.js';
import { privacyProjection, type PrivacyProjection } from './privacy.types.js';

export interface PrivacyRepository {
  read(userId: string): Promise<PrivacyProjection | null>;
  request(userId: string, requestId: string): Promise<PrivacyProjection>;
}
function project(row: { id: string; status: string; createdAt: Date; completedAt: Date | null }) {
  return privacyProjection.parse({
    id: row.id,
    status: row.status,
    requestedAt: row.createdAt.toISOString(),
    completedAt: row.completedAt?.toISOString() ?? null,
    erasureAutomaticallyEnabled: false,
  });
}
export function createPrivacyRepository(database: PrismaClient): PrivacyRepository {
  return {
    async read(userId) {
      const row = await database.privacyRequest.findUnique({ where: { userId } });
      return row ? project(row) : null;
    },
    async request(userId, requestId) {
      return database.$transaction(
        async (tx) => {
          const owners = await tx.$queryRaw<
            { id: string }[]
          >`SELECT id FROM users WHERE id=${userId}::uuid AND role='FARMER' AND status='ACTIVE' FOR UPDATE`;
          if (!owners.length) throw new AppError('AUTHENTICATION_ERROR');
          const previous = await tx.privacyRequest.findUnique({ where: { userId } });
          if (previous) return project(previous);
          const row = await tx.privacyRequest.create({ data: { userId } });
          await tx.auditLog.create({
            data: {
              actorId: userId,
              action: 'CREATE',
              entityType: 'privacy_request',
              entityId: row.id,
              requestId,
              changes: { status: 'REQUESTED', erasureEnabled: false },
            },
          });
          return project(row);
        },
        { maxWait: 10000, timeout: 15000 },
      );
    },
  };
}
