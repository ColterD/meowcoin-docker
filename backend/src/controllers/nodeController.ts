// backend/src/controllers/nodeController.ts
import { Request, Response } from 'express';
import { 
  getNodeStatus, 
  saveNodeSettings, 
  restartNode, 
  shutdownNode, 
  updateNode 
} from '../services/nodeService';
import { 
  getContainerLogs, 
  getDiskUsageDetails 
} from '../services/systemService';
import { SettingsRequest, NodeControlRequest, UpdateRequest } from '../types';

// Standard error response handler
const handleError = (res: Response, error: unknown, message: string) => {
  console.error(`${message}:`, error);
  const errorMessage = error instanceof Error ? error.message : 'Unknown error';
  res.status(500).json({ 
    success: false, 
    message: `${message}: ${errorMessage}` 
  });
};

// Get node status
export async function getStatus(req: Request, res: Response) {
  try {
    const status = await getNodeStatus();
    if (!status) {
      return res.status(500).json({ success: false, message: 'Failed to get node status' });
    }
    res.json(status);
  } catch (error) {
    handleError(res, error, 'Error in getStatus controller');
  }
}

// Get disk usage details
export async function getDiskUsage(req: Request, res: Response) {
  try {
    const diskUsage = await getDiskUsageDetails();
    res.json(diskUsage);
  } catch (error) {
    handleError(res, error, 'Error in getDiskUsage controller');
  }
}

// Get logs
export async function getLogs(req: Request, res: Response) {
  try {
    // Validate and parse since parameter
    let since = 0;
    if (req.query.since !== undefined) {
      const parsedSince = parseInt(req.query.since as string, 10);
      if (isNaN(parsedSince) || parsedSince < 0) {
        return res.status(400).json({ 
          success: false, 
          message: 'Invalid since parameter. Must be a positive number.' 
        });
      }
      since = parsedSince;
    }
    
    const logs = await getContainerLogs(since);
    res.json(logs);
  } catch (error) {
    handleError(res, error, 'Error in getLogs controller');
  }
}

// Save settings
export async function saveSettings(req: Request, res: Response) {
  try {
    const settings: SettingsRequest = req.body;
    
    // Validate settings
    if (
      typeof settings.maxConnections !== 'number' || 
      !Number.isInteger(settings.maxConnections) ||
      settings.maxConnections < 1 || 
      settings.maxConnections > 125
    ) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid maxConnections value. Must be an integer between 1 and 125.' 
      });
    }
    
    if (settings.enableTxindex !== 0 && settings.enableTxindex !== 1) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid enableTxindex value. Must be 0 or 1.' 
      });
    }
    
    const success = await saveNodeSettings(settings);
    
    if (!success) {
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to save settings' 
      });
    }
    
    res.json({ 
      success: true, 
      message: 'Settings updated. A restart may be required for changes to take effect.' 
    });
  } catch (error) {
    handleError(res, error, 'Error in saveSettings controller');
  }
}

// Control node (restart/shutdown)
export async function controlNode(req: Request, res: Response) {
  try {
    const request: NodeControlRequest = req.body;
    
    // Validate action parameter
    if (!request || !request.action) {
      return res.status(400).json({
        success: false,
        message: 'Missing required action parameter'
      });
    }
    
    if (request.action === 'restart') {
      const success = await restartNode();
      if (!success) {
        return res.status(500).json({ 
          success: false, 
          message: 'Failed to restart node' 
        });
      }
      
      res.json({ 
        success: true, 
        message: 'Restart initiated. The dashboard will reconnect when the node is back online.' 
      });
    } else if (request.action === 'shutdown') {
      const success = await shutdownNode();
      if (!success) {
        return res.status(500).json({ 
          success: false, 
          message: 'Failed to shutdown node' 
        });
      }
      
      res.json({ 
        success: true, 
        message: 'Shutdown initiated. You will need to restart the container manually.' 
      });
    } else {
      res.status(400).json({ 
        success: false, 
        message: `Invalid action: ${request.action}. Valid actions are 'restart' or 'shutdown'.` 
      });
    }
  } catch (error) {
    handleError(res, error, 'Error in controlNode controller');
  }
}

// Update node
export async function performUpdate(req: Request, res: Response) {
  try {
    const request: UpdateRequest = req.body;
    
    // Validate version parameter
    if (!request || !request.version) {
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required version parameter' 
      });
    }
    
    // Basic version format validation (e.g., Meow-v2.0.5)
    const versionPattern = /^Meow-v\d+\.\d+\.\d+$/;
    if (!versionPattern.test(request.version)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid version format. Expected format: Meow-vX.Y.Z'
      });
    }
    
    const success = await updateNode(request.version);
    
    if (!success) {
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to initiate update' 
      });
    }
    
    res.json({ 
      success: true, 
      message: 'Update initiated. The node will restart when complete.' 
    });
  } catch (error) {
    handleError(res, error, 'Error in performUpdate controller');
  }
}