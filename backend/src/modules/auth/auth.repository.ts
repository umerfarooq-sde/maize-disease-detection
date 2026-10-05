import { Prisma, type PrismaClient, type UserRole } from '../../generated/prisma/client.js';
import type { LoginAccount, SessionRecord } from './auth.types.js';

export type AuthDatabase = Pick<PrismaClient, 'user' | 'authSession' | '$transaction'>;
export interface AuthRepository {
  createAccount(input: {
    email: string;
    passwordHash: string;
    role: UserRole;
  }): Promise<LoginAccount | null>;
  findAccount(email: string): Promise<LoginAccount | null>;
  createSession(input: {
    id: string;
    userId: string;
    refreshTokenHash: string;
    expiresAt: Date;
  }): Promise<void>;
  findSession(id: string): Promise<SessionRecord | null>;
  rotateSession(
    id: string,
    expectedHash: string,
    nextHash: string,
    now: Date,
  ): Promise<SessionRecord | null>;
  revokeSession(id: string, now: Date): Promise<void>;
}

const accountSelect = { id: true, email: true, role: true, status: true, createdAt: true } as const;
const loginSelect = { ...accountSelect, passwordHash: true } as const;
const sessionInclude = { user: { select: accountSelect } } as const;

export function createAuthRepository(database: AuthDatabase): AuthRepository {
  return {
    async createAccount(input) {
      try {
        return await database.user.create({ data: input, select: loginSelect });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
          return null;
        throw error;
      }
    },
    findAccount(email) {
      return database.user.findUnique({ where: { email }, select: loginSelect });
    },
    async createSession(input) {
      await database.authSession.create({ data: input, select: { id: true } });
    },
    findSession(id) {
      return database.authSession.findUnique({ where: { id }, include: sessionInclude });
    },
    rotateSession(id, expectedHash, nextHash, now) {
      return database.$transaction(
        async (transaction) => {
          // Conditional UPDATE acquires a row lock and atomically consumes the
          // current hash. PostgreSQL rechecks predicates after concurrent updates.
          const consumed = await transaction.authSession.updateMany({
            where: {
              id,
              refreshTokenHash: expectedHash,
              revokedAt: null,
              expiresAt: { gt: now },
              user: { status: 'ACTIVE' },
            },
            data: { refreshTokenHash: nextHash },
          });
          if (consumed.count !== 1) {
            // Return after commit; throwing here would roll back replay revocation.
            await transaction.authSession.updateMany({
              where: { id, revokedAt: null },
              data: { revokedAt: now },
            });
            return null;
          }
          return transaction.authSession.findUnique({ where: { id }, include: sessionInclude });
        },
        { maxWait: 10000, timeout: 15000 },
      );
    },
    async revokeSession(id, now) {
      await database.authSession.updateMany({
        where: { id, revokedAt: null },
        data: { revokedAt: now },
      });
    },
  };
}
