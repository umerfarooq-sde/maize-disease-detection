import type { RequestHandler } from 'express';
import type { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import { clearRefreshCookie, readRefreshCookie, writeRefreshCookie } from './auth.cookies.js';
import type { AuthService } from './auth.service.js';
import type { SessionGrant } from './auth.types.js';
import type { loginRequest, registerRequest } from './auth.validators.js';

export function createAuthController(environment: Environment, service: AuthService) {
  function respondWithGrant(response: Parameters<RequestHandler>[1], grant: SessionGrant): void {
    writeRefreshCookie(response, environment, grant.refreshToken, grant.refreshExpiresAt);
    sendSuccess(response, {
      accessToken: grant.accessToken,
      tokenType: 'Bearer',
      expiresIn: grant.accessExpiresIn,
      user: grant.user,
    });
  }
  const register: RequestHandler = async (_request, response) => {
    const input = response.locals.validated as z.infer<typeof registerRequest>;
    sendSuccess(response, { user: await service.register(input.body) }, 201);
  };
  const login: RequestHandler = async (_request, response) => {
    const input = response.locals.validated as z.infer<typeof loginRequest>;
    respondWithGrant(response, await service.login(input.body));
  };
  const refresh: RequestHandler = async (request, response) => {
    try {
      respondWithGrant(response, await service.refresh(readRefreshCookie(request, environment)));
    } catch (error) {
      if (error instanceof AppError && error.status === 401)
        clearRefreshCookie(response, environment);
      throw error;
    }
  };
  const logout: RequestHandler = async (request, response) => {
    try {
      await service.logout(readRefreshCookie(request, environment));
    } finally {
      clearRefreshCookie(response, environment);
    }
    sendSuccess(response, { loggedOut: true });
  };
  const me: RequestHandler = (_request, response) => {
    if (!response.locals.principal) throw new AppError('AUTHENTICATION_ERROR');
    sendSuccess(response, { user: response.locals.principal.user });
  };
  return { register, login, refresh, logout, me };
}
