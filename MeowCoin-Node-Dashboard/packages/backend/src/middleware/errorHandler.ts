import { Request, Response, NextFunction } from 'express';
import { AppError, ErrorCodes, isAppError } from '@meowcoin/shared';

export const errorHandler = (
  err: Error | AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  console.error('Error occurred:', err);

  if (isAppError(err)) {
    res.status(err.status).json({
      success: false,
      message: err.message,
      code: err.code,
    });
    return;
  }

  // For regular errors, use a generic 500 response
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    code: ErrorCodes.INTERNAL_ERROR,
  });
};

// Catch 404 errors
export const notFoundHandler = (
  req: Request,
  res: Response
): void => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
    code: ErrorCodes.NOT_FOUND,
  });
};