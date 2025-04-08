import express from 'express';
import { validateConfig } from '../middleware/validate';
import { adminMiddleware } from '../middleware/auth';
import configService from '../config';
import { AppError, ErrorCodes } from '@meowcoin/shared';

const router = express.Router();

// Get current configuration
router.get('/', (req, res) => {
  const config = {
    port: configService.port,
    syncInterval: configService.syncInterval,
    maxConnections: configService.maxConnections,
  };
  
  res.json({ success: true, data: config });
});

// Update configuration (admin only)
router.patch('/', adminMiddleware, validateConfig, (req, res) => {
  try {
    configService.updateConfig(req.body);
    
    const updatedConfig = {
      port: configService.port,
      syncInterval: configService.syncInterval,
      maxConnections: configService.maxConnections,
    };
    
    res.json({ success: true, data: updatedConfig });
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    throw new AppError(ErrorCodes.INTERNAL_ERROR, 'Failed to update configuration', 500);
  }
});

export default router;
