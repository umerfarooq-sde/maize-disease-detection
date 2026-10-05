import type { ErrorRequestHandler, RequestHandler } from 'express';
import type { Logger } from 'pino';
import { AppError } from '../errors/app-error.js';
import type { ErrorResponse } from '../types/api.js';

export const notFound: RequestHandler = (_request, _response, next) =>
  next(new AppError('NOT_FOUND'));

function normalizeError(error: unknown): AppError {
  if (error instanceof AppError) return error;
  if (typeof error === 'object' && error !== null && 'type' in error) {
    switch (error.type) {
      case 'entity.parse.failed':
      case 'request.aborted':
      case 'request.size.invalid':
        return new AppError('VALIDATION_ERROR');
      case 'entity.too.large':
        return new AppError('PAYLOAD_TOO_LARGE');
      case 'encoding.unsupported':
      case 'charset.unsupported':
        return new AppError('UNSUPPORTED_MEDIA_TYPE');
    }
  }
  return new AppError('INTERNAL_SERVER_ERROR');
}

export function errorHandler(logger: Logger): ErrorRequestHandler {
  return (error: unknown, _request, response, next) => {
    const applicationError = normalizeError(error);
    if (applicationError.status >= 500) {
      // Raw dependency errors can contain connection URLs, queries or submitted values.
      logger.error(
        { requestId: response.locals.requestId, code: applicationError.code },
        'Request failed',
      );
    }
    if (response.headersSent) {
      next(applicationError);
      return;
    }
    const body: ErrorResponse = {
      success: false,
      error: {
        code: applicationError.code,
        message: applicationError.message,
        ...(applicationError.code === 'VALIDATION_ERROR' && applicationError.details
          ? { details: applicationError.details }
          : {}),
      },
      requestId: response.locals.requestId,
    };
    response.status(applicationError.status).json(body);
  };
}
