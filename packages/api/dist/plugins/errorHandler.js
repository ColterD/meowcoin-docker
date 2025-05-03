"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = errorHandler;
const zod_1 = require("zod");
const shared_1 = require("@meowcoin/shared");
const logger_1 = require("../utils/logger");
function errorHandler(error, request, reply) {
    // Log the error
    logger_1.logger.error({
        err: error,
        path: request.url,
        method: request.method,
        ip: request.ip,
    }, 'Request error');
    // Handle AppError (custom application errors)
    if (error instanceof shared_1.AppError) {
        return reply.status(error.statusCode).send({
            success: false,
            message: error.message,
            code: error.code,
            timestamp: new Date().toISOString(),
            details: error.details,
        });
    }
    // Handle Zod validation errors
    if (error instanceof zod_1.ZodError) {
        return reply.status(400).send({
            success: false,
            message: 'Validation error',
            code: shared_1.ErrorCode.VALIDATION_ERROR,
            timestamp: new Date().toISOString(),
            details: error.format(),
        });
    }
    // Handle Fastify validation errors
    if (error.validation) {
        return reply.status(400).send({
            success: false,
            message: 'Validation error',
            code: shared_1.ErrorCode.VALIDATION_ERROR,
            timestamp: new Date().toISOString(),
            details: error.validation,
        });
    }
    // Handle JWT authentication errors
    if (error.code === 'FST_JWT_NO_AUTHORIZATION_IN_HEADER' ||
        error.code === 'FST_JWT_AUTHORIZATION_TOKEN_EXPIRED' ||
        error.code === 'FST_JWT_AUTHORIZATION_TOKEN_INVALID') {
        return reply.status(401).send({
            success: false,
            message: 'Authentication required',
            code: shared_1.ErrorCode.UNAUTHORIZED,
            timestamp: new Date().toISOString(),
        });
    }
    // Handle 404 errors
    if (error.statusCode === 404) {
        return reply.status(404).send({
            success: false,
            message: 'Resource not found',
            code: shared_1.ErrorCode.NOT_FOUND,
            timestamp: new Date().toISOString(),
        });
    }
    // Handle all other errors
    const statusCode = error.statusCode || 500;
    // Don't expose internal error details in production
    const message = process.env.NODE_ENV === 'production' && statusCode === 500
        ? 'Internal server error'
        : error.message || 'Something went wrong';
    return reply.status(statusCode).send({
        success: false,
        message,
        code: shared_1.ErrorCode.INTERNAL_SERVER_ERROR,
        timestamp: new Date().toISOString(),
    });
}
