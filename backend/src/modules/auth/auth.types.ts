import type { User, UserRole } from '../../generated/prisma/client.js';

export type Account = Pick<User, 'id' | 'email' | 'role' | 'status' | 'createdAt'>;
export type LoginAccount = Account & Pick<User, 'passwordHash'>;
export interface PublicAccount {
  email: string;
  role: UserRole;
  createdAt: string;
}
export interface SessionRecord {
  id: string;
  userId: string;
  refreshTokenHash: string;
  expiresAt: Date;
  revokedAt: Date | null;
  user: Account;
}
export interface Principal {
  userId: string;
  sessionId: string;
  role: UserRole;
  user: PublicAccount;
}
export interface Credentials {
  email: string;
  password: string;
}
export interface SessionGrant {
  accessToken: string;
  refreshToken: string;
  accessExpiresIn: number;
  refreshExpiresAt: Date;
  user: PublicAccount;
}
