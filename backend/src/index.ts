import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import path from 'path';
import { setupNodeMonitor } from './services/nodeMonitor';
import { setupDiskMonitor } from './services/diskMonitor';
import nodeRoutes from './routes/nodeRoutes';
import { environment } from './config/environment';

// Create Express app
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// API routes
app.use('/api', nodeRoutes);

// Determine static file directory based on environment
const staticDir = environment.isDevelopment
  ? path.join(__dirname, '../../frontend/dist')
  : '/var/www/html';

// Static file serving
app.use(express.static(staticDir));

// Set up Socket.IO connection
io.on('connection', (socket) => {
  console.log('Client connected');
  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });
});

// Start monitors
setupNodeMonitor(io);
setupDiskMonitor(io);

// Handle 404s for SPA
app.get('*', (req, res) => {
  res.sendFile(path.resolve(staticDir, 'index.html'));
});

// Start server
const PORT = environment.port;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});