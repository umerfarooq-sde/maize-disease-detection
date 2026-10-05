import { randomUUID } from 'node:crypto';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { hashPassword, verifyPassword } from './auth.password.js';
import type { AuthRepository } from './auth.repository.js';
import { createTokenService, tokenHash } from './auth.tokens.js';
import type { Account, Credentials, Principal, PublicAccount, SessionGrant } from './auth.types.js';

function publicAccount(account: Account): PublicAccount {
  return { email: account.email, role: account.role, createdAt: account.createdAt.toISOString() };
}

export function createAuthService(
  environment: Environment,
  repository: AuthRepository,
  now: () => Date = () => new Date(),
) {
  const tokens = createTokenService(environment, now);
  async function createAccount(
    credentials: Credentials,
    role: 'FARMER' | 'ADMIN',
  ): Promise<PublicAccount> {
    const account = await repository.createAccount({
      email: credentials.email,
      passwordHash: await hashPassword(credentials.password),
      role,
    });
    if (!account) throw new AppError('ACCOUNT_EXISTS');
    return publicAccount(account);
  }
  return {
    register(credentials: Credentials) {
      return createAccount(credentials, 'FARMER');
    },
    // Operator CLI only; no HTTP route exposes this method.
    createAdmin(credentials: Credentials) {
      return createAccount(credentials, 'ADMIN');
    },
    async login(credentials: Credentials): Promise<SessionGrant> {
      const account = await repository.findAccount(credentials.email);
      const matches = await verifyPassword(account?.passwordHash, credentials.password);
      if (!account || !matches || account.status !== 'ACTIVE')
        throw new AppError('INVALID_CREDENTIALS');
      const id = randomUUID();
      const expiresAt = new Date(now().getTime() + environment.JWT_REFRESH_TTL_SECONDS * 1000);
      const grant = await tokens.issue(id, expiresAt);
      await repository.createSession({
        id,
        userId: account.id,
        refreshTokenHash: tokenHash(grant.refreshToken),
        expiresAt,
      });
      return { ...grant, refreshExpiresAt: expiresAt, user: publicAccount(account) };
    },
    async refresh(token: string): Promise<SessionGrant> {
      const id = await tokens.verify(token, 'refresh');
      const existing = await repository.findSession(id);
      if (!existing || existing.revokedAt || existing.expiresAt <= now())
        throw new AppError('AUTHENTICATION_ERROR');
      const grant = await tokens.issue(id, existing.expiresAt);
      const rotated = await repository.rotateSession(
        id,
        tokenHash(token),
        tokenHash(grant.refreshToken),
        now(),
      );
      if (!rotated) throw new AppError('AUTHENTICATION_ERROR');
      return { ...grant, refreshExpiresAt: existing.expiresAt, user: publicAccount(rotated.user) };
    },
    async logout(token: string): Promise<void> {
      const id = await tokens.verify(token, 'refresh');
      // A valid old token may revoke its own family, but can never mint new tokens.
      await repository.revokeSession(id, now());
    },
    async authenticate(token: string): Promise<Principal> {
      const id = await tokens.verify(token, 'access');
      const session = await repository.findSession(id);
      if (
        !session ||
        session.revokedAt ||
        session.expiresAt <= now() ||
        session.user.status !== 'ACTIVE'
      )
        throw new AppError('AUTHENTICATION_ERROR');
      return {
        userId: session.userId,
        sessionId: id,
        role: session.user.role,
        user: publicAccount(session.user),
      };
    },
  };
}

export type AuthService = ReturnType<typeof createAuthService>;
