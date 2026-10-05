import { parseCookie, stringifySetCookie } from 'cookie';
import type { Request, Response } from 'express';
import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';

export function refreshCookieName(environment: Environment): string {
  return environment.NODE_ENV === 'production'
    ? '__Host-maizedoctor_refresh'
    : 'maizedoctor_refresh';
}
export function readRefreshCookie(request: Request, environment: Environment): string {
  const token = z
    .string()
    .min(1)
    .max(4096)
    .safeParse(parseCookie(request.get('cookie') ?? '')[refreshCookieName(environment)]);
  if (!token.success) throw new AppError('AUTHENTICATION_ERROR');
  return token.data;
}
export function writeRefreshCookie(
  response: Response,
  environment: Environment,
  token: string,
  expiresAt: Date,
): void {
  response.append(
    'Set-Cookie',
    stringifySetCookie({
      name: refreshCookieName(environment),
      value: token,
      path: '/',
      httpOnly: true,
      secure: environment.NODE_ENV === 'production',
      sameSite: 'strict',
      expires: expiresAt,
    }),
  );
}
export function clearRefreshCookie(response: Response, environment: Environment): void {
  response.append(
    'Set-Cookie',
    stringifySetCookie({
      name: refreshCookieName(environment),
      value: '',
      path: '/',
      httpOnly: true,
      secure: environment.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 0,
      expires: new Date(0),
    }),
  );
}
