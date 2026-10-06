import type { RequestHandler } from 'express';
import { z } from 'zod';
import { AppError } from '../errors/app-error.js';
import type { AuthService } from '../modules/auth/auth.service.js';

const bearer = z
  .string()
  .max(4096)
  .regex(/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/i);

export function authenticate(service: AuthService): RequestHandler {
  return async (request, response, next) => {
    const header = bearer.safeParse(request.get('authorization'));
    if (!header.success) throw new AppError('AUTHENTICATION_ERROR');
    response.locals.principal = await service.authenticate(header.data.slice(7));
    next();
  };
}

export function optionallyAuthenticate(service: AuthService): RequestHandler {
  const required = authenticate(service);
  return (request, response, next) => {
    if (request.get('authorization') === undefined) return next();
    return required(request, response, next);
  };
}
