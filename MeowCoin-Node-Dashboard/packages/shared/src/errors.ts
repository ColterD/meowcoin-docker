export class AppError extends Error {
  constructor(public code: string, message: string, public status = 500) {
    super(message);
    this.name = 'AppError';
  }
}

export const ErrorCodes = {
  NETWORK_ERROR: 'NETWORK_ERROR',
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  NODE_UNAVAILABLE: 'NODE_UNAVAILABLE',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  UNKNOWN_ERROR: 'UNKNOWN_ERROR',
};

export const isAppError = (error: unknown): error is AppError => {
  return error instanceof AppError;
};

export const createErrorFromResponse = (
  status: number, 
  message = 'Unknown error',
  code = ErrorCodes.UNKNOWN_ERROR
): AppError => {
  return new AppError(code, message, status);
};