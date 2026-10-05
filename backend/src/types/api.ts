export interface ValidationIssue {
  path: string;
  code: string;
}

export interface SuccessResponse<T> {
  success: true;
  data: T;
  requestId: string;
}

export interface ErrorResponse {
  success: false;
  error: { code: string; message: string; details?: ValidationIssue[] };
  requestId: string;
}
