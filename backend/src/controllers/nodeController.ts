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

// Get node status
export async function getStatus(req: Request, res: Response) {
  try {
    const status = await getNodeStatus();
    if (!status) {
      return res.status(500).json({ error: 'Failed to get node status' });
    }
    res.json(status);
  } catch (error) {
    console.error('Error in getStatus controller:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

// Get disk usage details
export async function getDiskUsage(req: Request, res: Response) {
  try {
    const diskUsage = await getDiskUsageDetails();
    res.json(diskUsage);
  } catch (error) {
    console.error('Error in getDiskUsage controller:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

// Get logs
export async function getLogs(req: Request, res: Response) {
  try {
    const since = parseInt(req.query.since as string, 10) || 0;
    const logs = await getContainerLogs(since);
    res.json(logs);
  } catch (error) {
    console.error('Error in getLogs controller:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

// Save settings
export async function saveSettings(req: Request, res: Response) {
  try {
    const settings: SettingsRequest = req.body;
    
    // Validate settings
    if (
      typeof settings.maxConnections !== 'number' || 
      settings.maxConnections < 1 || 
      settings.maxConnections > 125
    ) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid maxConnections value' 
      });
    }
    
    if (settings.enableTxindex !== 0 && settings.enableTxindex !== 1) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid enableTxindex value' 
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
    console.error('Error in saveSettings controller:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
}

// Control node (restart/shutdown)
export async function controlNode(req: Request, res: Response) {
  try {
    const request: NodeControlRequest = req.body;
    
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
        message: 'Invalid action' 
      });
    }
  } catch (error) {
    console.error('Error in controlNode controller:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
}

// Update node
export async function performUpdate(req: Request, res: Response) {
  try {
    const request: UpdateRequest = req.body;
    
    if (!request.version) {
      return res.status(400).json({ 
        success: false, 
        message: 'No version specified' 
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
    console.error('Error in performUpdate controller:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
}