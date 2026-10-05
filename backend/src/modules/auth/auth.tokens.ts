import { createHash, randomBytes } from 'node:crypto';
import { jwtVerify, SignJWT } from 'jose';
import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';

const claims = z.object({
  sub: z.uuid(),
  jti: z.string().regex(/^[a-f0-9]{64}$/),
  purpose: z.enum(['access', 'refresh']),
  iat: z.number().int(),
  exp: z.number().int(),
});
export const tokenHash = (token: string): string =>
  createHash('sha256').update(token).digest('hex');

export function createTokenService(environment: Environment, now: () => Date) {
  const keys = {
    access: Buffer.from(environment.JWT_SECRET, 'base64url'),
    refresh: Buffer.from(environment.JWT_REFRESH_SECRET, 'base64url'),
  };
  const audience = { access: 'maizedoctor-api', refresh: 'maizedoctor-refresh' };
  return {
    async issue(sessionId: string, expiresAt: Date) {
      const issued = Math.floor(now().getTime() / 1000);
      const refreshExpires = Math.floor(expiresAt.getTime() / 1000);
      const accessExpires = Math.min(issued + environment.JWT_ACCESS_TTL_SECONDS, refreshExpires);
      async function sign(purpose: 'access' | 'refresh', expires: number) {
        return new SignJWT({ purpose })
          .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
          .setSubject(sessionId)
          .setJti(randomBytes(32).toString('hex'))
          .setIssuer(environment.JWT_ISSUER)
          .setAudience(audience[purpose])
          .setIssuedAt(issued)
          .setExpirationTime(expires)
          .sign(keys[purpose]);
      }
      return {
        accessToken: await sign('access', accessExpires),
        refreshToken: await sign('refresh', refreshExpires),
        accessExpiresIn: accessExpires - issued,
      };
    },
    async verify(token: string, purpose: 'access' | 'refresh'): Promise<string> {
      try {
        const { payload } = await jwtVerify(token, keys[purpose], {
          algorithms: ['HS256'],
          typ: 'JWT',
          issuer: environment.JWT_ISSUER,
          audience: audience[purpose],
          currentDate: now(),
          requiredClaims: ['sub', 'jti', 'iat', 'exp', 'purpose'],
        });
        const parsed = claims.parse(payload);
        if (
          parsed.purpose !== purpose ||
          parsed.exp <= parsed.iat ||
          parsed.iat > Math.floor(now().getTime() / 1000)
        )
          throw new Error('Invalid token claims');
        return parsed.sub;
      } catch {
        throw new AppError('AUTHENTICATION_ERROR');
      }
    },
  };
}
