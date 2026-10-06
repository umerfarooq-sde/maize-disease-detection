import type { ValidationIssue } from '../types/api.js';

const errorDefinitions = {
  VALIDATION_ERROR: { status: 400, message: 'Request validation failed.' },
  AUTHENTICATION_ERROR: { status: 401, message: 'Authentication is required.' },
  AUTHORIZATION_ERROR: { status: 403, message: 'Access is forbidden.' },
  NOT_FOUND: { status: 404, message: 'Resource not found.' },
  CONFLICT: { status: 409, message: 'The request conflicts with the current state.' },
  ACCOUNT_EXISTS: { status: 409, message: 'An account with this email already exists.' },
  INVALID_CREDENTIALS: { status: 401, message: 'Email or password is incorrect.' },
  RATE_LIMITED: { status: 429, message: 'Too many requests. Please try again later.' },
  PAYLOAD_TOO_LARGE: { status: 413, message: 'Request body is too large.' },
  UNSUPPORTED_MEDIA_TYPE: {
    status: 415,
    message: 'Request content type or encoding is not supported.',
  },
  INTERNAL_SERVER_ERROR: { status: 500, message: 'An unexpected error occurred.' },
  INVALID_IMAGE: {
    status: 400,
    message: 'The image is invalid, damaged, animated or too large in dimensions.',
  },
  UPLOAD_UNAVAILABLE: {
    status: 503,
    message: 'Image upload is temporarily unavailable. Please try again later.',
  },
  UPLOAD_FAILED: { status: 502, message: 'The image could not be stored. Please try again.' },
  UPLOAD_IN_PROGRESS: {
    status: 409,
    message: 'This upload is already being processed. Please retry shortly.',
  },
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
