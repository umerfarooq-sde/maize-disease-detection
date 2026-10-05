import type { ValidationIssue } from '../types/api.js';

const errorDefinitions = {
  VALIDATION_ERROR: { status: 400, message: 'Request validation failed.' },
  AUTHENTICATION_ERROR: { status: 401, message: 'Authentication is required.' },
  AUTHORIZATION_ERROR: { status: 403, message: 'Access is forbidden.' },
  NOT_FOUND: { status: 404, message: 'Resource not found.' },
  CONFLICT: { status: 409, message: 'The request conflicts with the current state.' },
  RATE_LIMITED: { status: 429, message: 'Too many requests. Please try again later.' },
  PAYLOAD_TOO_LARGE: { status: 413, message: 'Request body is too large.' },
  UNSUPPORTED_MEDIA_TYPE: { status: 415, message: 'Request encoding is not supported.' },
  INTERNAL_SERVER_ERROR: { status: 500, message: 'An unexpected error occurred.' },
} as const;

export type ErrorCode = keyof typeof errorDefinitions;

export class AppError extends Error {
  readonly status: number;

  constructor(
    readonly code: ErrorCode,
    readonly details?: ValidationIssue[],
  ) {
    super(errorDefinitions[code].message);
    this.name = 'AppError';
    this.status = errorDefinitions[code].status;
  }
}
