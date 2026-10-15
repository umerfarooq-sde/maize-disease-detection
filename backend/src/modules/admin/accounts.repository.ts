import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { AppError } from '../../errors/app-error.js';
import {
  type AuditQuery,
  type FarmerQuery,
  type FarmerRow,
  type StatusPatch,
  accountRevision,
} from './accounts.types.js';

const farmerSelect = {
  id: true,
  email: true,
  status: true,
  createdAt: true,
  updatedAt: true,
  farmerProfile: { select: { displayName: true } },
} as const satisfies Prisma.UserSelect;
const auditSelect = {
  id: true,
  action: true,
  entityType: true,
  entityId: true,
  createdAt: true,
  changes: true,
  actor: { select: { id: true, role: true } },
} as const satisfies Prisma.AuditLogSelect;
export type AuditRow = Prisma.AuditLogGetPayload<{ select: typeof auditSelect }>;
export interface AccountsRepository {
  farmers(query: FarmerQuery): Promise<{ items: FarmerRow[]; nextCursor: string | null }>;
  status(id: string, input: StatusPatch, actorId: string, requestId: string): Promise<FarmerRow>;
  audits(query: AuditQuery): Promise<{ items: AuditRow[]; nextCursor: string | null }>;
}
export function createAccountsRepository(database: PrismaClient): AccountsRepository {
  return {
    async farmers(query) {
      if (
        query.cursor &&
        !(await database.user.findFirst({
          where: { id: query.cursor, role: 'FARMER' },
          select: { id: true },
        }))
      )
        throw new AppError('NOT_FOUND');
      const rows = await database.user.findMany({
        where: {
          role: 'FARMER',
          ...(query.status ? { status: query.status } : {}),
          ...(query.email ? { email: query.email } : {}),
        },
        select: farmerSelect,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: query.limit + 1,
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
      });
      const items = rows.slice(0, query.limit);
      return { items, nextCursor: rows.length > query.limit ? (items.at(-1)?.id ?? null) : null };
    },
    status(id, input, actorId, requestId) {
      return database.$transaction(
        async (tx) => {
          const rows = await tx.$queryRaw<
            { id: string }[]
          >`SELECT id FROM users WHERE id=${id}::uuid AND role='FARMER' FOR UPDATE`;
          if (!rows.length) throw new AppError('NOT_FOUND');
          const row = await tx.user.findUniqueOrThrow({ where: { id }, select: farmerSelect });
          if (accountRevision(row) !== input.expectedRevision || row.status === input.status)
            throw new AppError('CONFLICT');
          const updated = await tx.user.update({
            where: { id },
            data: {
              status: input.status,
              updatedAt: new Date(Math.max(Date.now(), row.updatedAt.getTime() + 1)),
            },
            select: farmerSelect,
          });
          const revoked = await tx.authSession.updateMany({
            where: { userId: id, revokedAt: null },
            data: { revokedAt: new Date() },
          });
          await tx.auditLog.create({
            data: {
              actorId,
              requestId,
              entityType: 'farmer_account',
              entityId: id,
              action: input.status === 'ACTIVE' ? 'ACTIVATE' : 'DEACTIVATE',
              changes: {
                fromStatus: row.status,
                toStatus: input.status,
                revokedSessions: revoked.count,
              },
            },
          });
          return updated;
        },
        { maxWait: 10000, timeout: 15000 },
      );
    },
    async audits(query) {
      if (
        query.cursor &&
        !(await database.auditLog.findUnique({ where: { id: query.cursor }, select: { id: true } }))
      )
        throw new AppError('NOT_FOUND');
      const where: Prisma.AuditLogWhereInput = {
        ...(query.action ? { action: query.action } : {}),
        ...(query.entityType ? { entityType: query.entityType } : {}),
        ...(query.actorId ? { actorId: query.actorId } : {}),
        ...(query.from && query.to
          ? {
              createdAt: {
                gte: new Date(`${query.from}T00:00:00.000Z`),
                lt: new Date(Date.parse(query.to) + 86400000),
              },
            }
          : {}),
      };
      const rows = await database.auditLog.findMany({
        where,
        select: auditSelect,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: query.limit + 1,
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
      });
      const items = rows.slice(0, query.limit);
      return { items, nextCursor: rows.length > query.limit ? (items.at(-1)?.id ?? null) : null };
    },
  };
}
