import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AppError, ErrorCodes, UserData } from '@meowcoin/shared';
import configService from '../config';

// Augment the Express Request type
declare global {
  namespace Express {
    interface Request {
      user?: UserData;
    }
  }
}

export const authMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  // Skip auth for specific paths
  const publicPaths = ['/api/auth/login', '/health'];
  if (publicPaths.includes(req.path)) {
    return next();
  }

  const token = req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    throw new AppError(ErrorCodes.UNAUTHORIZED, 'No authentication token provided', 401);
  }

  try {
    const decoded = jwt.verify(token, configService.jwtSecret) as UserData;
    req.user = decoded;
    next();
  } catch (error) {
    throw new AppError(ErrorCodes.UNAUTHORIZED, 'Invalid or expired token', 401);
  }
};

export const adminMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  if (!req.user) {
    throw new AppError(ErrorCodes.UNAUTHORIZED, 'Authentication required', 401);
  }

  if (req.user.role !== 'admin') {
    throw new AppError(ErrorCodes.FORBIDDEN, 'Admin access required', 403);
  }

  next();
};