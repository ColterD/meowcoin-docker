import express from 'express';
import { validateNodeAction } from '../middleware/validate';
import { adminMiddleware } from '../middleware/auth';
import nodeService from '../services/nodeService';
import { AppError, ErrorCodes } from '@meowcoin/shared';

const router = express.Router();

// Get all nodes status
router.get('/status', (req, res) => {
  const nodes = nodeService.getNodes();
  res.json({ success: true, data: nodes });
});

// Get specific node status by ID
router.get('/status/:id', (req, res) => {
  try {
    const node = nodeService.getNodeById(req.params.id);
    res.json({ success: true, data: node });
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    throw new AppError(ErrorCodes.INTERNAL_ERROR, 'Failed to get node status', 500);
  }
});

// Perform action on node (requires admin role)
router.post('/action', adminMiddleware, validateNodeAction, (req, res) => {
  try {
    const { id, action } = req.body;
    const updatedNode = nodeService.updateNodeStatus(id, action);
    res.json({ success: true, data: updatedNode });
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    throw new AppError(ErrorCodes.INTERNAL_ERROR, 'Failed to perform node action', 500);
  }
});

export default router;