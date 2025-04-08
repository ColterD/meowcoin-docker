import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import routes from './routes';
import configService from './config';
import { authMiddleware } from './middleware/auth';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import socketService from './services/socketService';
import nodeService from './services/nodeService';

// Create Express app
const app = express();
const httpServer = createServer(app);

// Initialize socket server
const io = socketService.initialize(httpServer);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(authMiddleware);

// Routes
app.use('/api', routes);

// Health check endpoint
app.get('/health', (_, res) => res.status(200).json({ status: 'healthy' }));

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

// Start server
const PORT = configService.port;
httpServer.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  
  // Start node monitoring
  nodeService.startMonitoring();
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  
  nodeService.stopMonitoring();
  
  httpServer.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});