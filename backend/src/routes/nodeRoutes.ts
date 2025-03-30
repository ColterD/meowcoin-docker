import { Router } from 'express';
import { 
  getStatus, 
  getDiskUsage, 
  getLogs, 
  saveSettings, 
  controlNode, 
  performUpdate 
} from '../controllers/nodeController';

const router = Router();

// Status endpoints
router.get('/status', getStatus);
router.get('/disk-usage', getDiskUsage);
router.get('/logs', getLogs);

// Control endpoints
router.post('/settings', saveSettings);
router.post('/control', controlNode);
router.post('/update', performUpdate);

export default router;