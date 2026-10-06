import type { RequestHandler } from 'express';
import { AppError } from '../errors/app-error.js';
import type { UserRole } from '../generated/prisma/client.js';

export function authorize(...roles: UserRole[]): RequestHandler {
  return (_request, response, next) => {
    const principal = response.locals.principal;
    if (!principal) throw new AppError('AUTHENTICATION_ERROR');
    if (!roles.includes(principal.role)) throw new AppError('AUTHORIZATION_ERROR');
    next();
  };
}

export function optionallyAuthorize(...roles: UserRole[]): RequestHandler {
  const required = authorize(...roles);
  return (request, response, next) => {
    if (!response.locals.principal) return next();
    return required(request, response, next);
  };
}
