import express from 'express';
import nodeRoutes from './node';
import configRoutes from './config';
import authRoutes from './auth';

const router = express.Router();

router.use('/node', nodeRoutes);
router.use('/config', configRoutes);
router.use('/auth', authRoutes);

export default router;
