import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { AppError, ErrorCodes, NODE_ACTIONS } from '@meowcoin/shared';

const nodeActionSchema = z.object({
  id: z.string(),
  action: z.enum([NODE_ACTIONS.START, NODE_ACTIONS.STOP, NODE_ACTIONS.RESTART]),
});

const configSchema = z.object({
  syncInterval: z.number().int().min(1000).optional(),
  maxConnections: z.number().int().positive().optional(),
});

export const validateNodeAction = (req: Request, res: Response, next: NextFunction): void => {
  try {
    nodeActionSchema.parse(req.body);
    next();
  } catch (error) {
    const validActions = Object.values(NODE_ACTIONS).join(', ');
    throw new AppError(
      ErrorCodes.VALIDATION_ERROR, 
      `Invalid node action. ID must be a string and action must be one of: ${validActions}`,
      400
    );
  }
};

export const validateConfig = (req: Request, res: Response, next: NextFunction): void => {
  try {
    configSchema.parse(req.body);
    next();
  } catch (error) {
    throw new AppError(
      ErrorCodes.VALIDATION_ERROR,
      'Invalid configuration values. Sync interval must be at least 1000ms and max connections must be positive.',
      400
    );
  }
};
