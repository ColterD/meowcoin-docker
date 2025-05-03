import { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';
import { AppError, ErrorCode } from '@meowcoin/shared';
import { logger } from '../utils/logger';

export function errorHandler(
  error: FastifyError | Error | ZodError | AppError,
  request: FastifyRequest,
  reply: FastifyReply
) {
  // Log the error
  logger.error({
    err: error,
    path: request.url,
    method: request.method,
    ip: request.ip,
  }, 'Request error');

  // Handle AppError (custom application errors)
  if (error instanceof AppError) {
    return reply.status(error.statusCode).send({
      success: false,
      message: error.message,
      code: error.code,
      timestamp: new Date().toISOString(),
      details: error.details,
    });
  }

  // Handle Zod validation errors
  if (error instanceof ZodError) {
    return reply.status(400).send({
      success: false,
      message: 'Validation error',
      code: ErrorCode.VALIDATION_ERROR,
      timestamp: new Date().toISOString(),
      details: error.format(),
    });
  }

  // Handle Fastify validation errors
  if ('validation' in error && error.validation) {
    return reply.status(400).send({
      success: false,
      message: 'Validation error',
      code: ErrorCode.VALIDATION_ERROR,
      timestamp: new Date().toISOString(),
      details: error.validation,
    });
  }

  // Handle JWT authentication errors
  if ('code' in error && (
      error.code === 'FST_JWT_NO_AUTHORIZATION_IN_HEADER' || 
      error.code === 'FST_JWT_AUTHORIZATION_TOKEN_EXPIRED' ||
      error.code === 'FST_JWT_AUTHORIZATION_TOKEN_INVALID')) {
    return reply.status(401).send({
      success: false,
      message: 'Authentication required',
      code: ErrorCode.UNAUTHORIZED,
      timestamp: new Date().toISOString(),
    });
  }

  // Handle 404 errors
  if ('statusCode' in error && error.statusCode === 404) {
    return reply.status(404).send({
      success: false,
      message: 'Resource not found',
      code: ErrorCode.NOT_FOUND,
      timestamp: new Date().toISOString(),
    });
  }

  // Handle all other errors
  const statusCode = 'statusCode' in error && typeof error.statusCode === 'number' ? error.statusCode : 500;
  
  // Don't expose internal error details in production
  const message = process.env.NODE_ENV === 'production' && statusCode === 500
    ? 'Internal server error'
    : error.message || 'Something went wrong';

  return reply.status(statusCode).send({
    success: false,
    message,
    code: ErrorCode.INTERNAL_SERVER_ERROR,
    timestamp: new Date().toISOString(),
  });
}