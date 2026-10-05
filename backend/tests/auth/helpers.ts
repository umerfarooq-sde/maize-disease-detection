import { randomUUID } from 'node:crypto';
import type { AuthRepository } from '../../src/modules/auth/auth.repository.js';
import type { LoginAccount, SessionRecord } from '../../src/modules/auth/auth.types.js';

// Isolated service/HTTP fixtures; PostgreSQL tests separately verify real locking.
export function memoryRepository() {
  const accounts = new Map<string, LoginAccount>();
  const sessions = new Map<string, SessionRecord>();
  const repository: AuthRepository = {
    async createAccount(input) {
      if (accounts.has(input.email)) return null;
      const account: LoginAccount = {
        ...input,
        id: randomUUID(),
        status: 'ACTIVE',
        createdAt: new Date(),
      };
      accounts.set(input.email, account);
      return account;
    },
    async findAccount(email) {
      return accounts.get(email) ?? null;
    },
    async createSession(input) {
      const user = [...accounts.values()].find((account) => account.id === input.userId);
      if (!user) throw new Error('Unknown fixture account');
      sessions.set(input.id, { ...input, revokedAt: null, user });
    },
    async findSession(id) {
      return sessions.get(id) ?? null;
    },
    async rotateSession(id, expected, next, now) {
      const session = sessions.get(id);
      if (!session || session.revokedAt) return null;
      if (
        session.refreshTokenHash !== expected ||
        session.expiresAt <= now ||
        session.user.status !== 'ACTIVE'
      ) {
        session.revokedAt = now;
        return null;
      }
      session.refreshTokenHash = next;
      return session;
    },
    async revokeSession(id, now) {
      const session = sessions.get(id);
      if (session && !session.revokedAt) session.revokedAt = now;
    },
  };
  return { repository, accounts, sessions };
}
