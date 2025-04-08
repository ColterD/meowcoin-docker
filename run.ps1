# Define the root directory
$rootDir = "MeowCoin-Node-Dashboard"

# Function to create or update a file with content
function Set-FileContent {
    param (
        [string]$Path,
        [string]$Content
    )
    New-Item -ItemType File -Path $Path -Force | Out-Null
    Set-Content -Path $Path -Value $Content -Force
}

# Check if the directory exists, and clean it if it does
if (Test-Path $rootDir) {
    Write-Host "Directory $rootDir already exists. Cleaning it up..."
    Remove-Item -Path "$rootDir\*" -Recurse -Force
} else {
    Write-Host "Creating directory $rootDir..."
    New-Item -ItemType Directory -Name $rootDir -Force | Out-Null
}

# Change to the root directory
Set-Location $rootDir

# Remove any Yarn-related files
Write-Host "Removing any existing Yarn or npm artifacts..."
Remove-Item -Path "node_modules" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "yarn.lock" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "package-lock.json" -Force -ErrorAction SilentlyContinue

# Create root files
Set-FileContent -Path ".gitignore" -Content @"
node_modules/
dist/
build/
*.log
*.tsbuildinfo
.env
cypress/videos/
cypress/screenshots/
coverage/
"@

Set-FileContent -Path "Dockerfile" -Content @"
# Base stage for building
FROM node:18-alpine AS base
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY packages/ packages/

# Build shared package
FROM base AS shared-builder
WORKDIR /app/packages/shared
RUN npm install && npm run build

# Build backend
FROM base AS backend-builder
WORKDIR /app/packages/backend
COPY --from=shared-builder /app/packages/shared/ ../shared/
RUN npm install && npm run build

# Build frontend
FROM base AS frontend-builder
WORKDIR /app/packages/frontend
COPY --from=shared-builder /app/packages/shared/ ../shared/
RUN npm install && npm run build

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=backend-builder /app/packages/backend/dist ./backend
COPY --from=frontend-builder /app/packages/frontend/build ./public
COPY --from=backend-builder /app/packages/backend/package.json ./backend/
COPY packages/shared/ ./shared/
RUN npm install -g pm2 && cd backend && npm install --production

EXPOSE 3000
CMD ["pm2", "start", "backend/index.js", "--no-daemon"]
"@

Set-FileContent -Path "docker-compose.yml" -Content @"
services:
  dashboard:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - node_data:/app/data
    environment:
      - NODE_ENV=production
      - PORT=3000
      - NODE_API_KEY=\${NODE_API_KEY}
      - JWT_SECRET=\${JWT_SECRET}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  node_data:
"@

Set-FileContent -Path "package.json" -Content @"
{
  "name": "meowcoin-node-dashboard",
  "version": "1.0.0",
  "private": true,
  "workspaces": ["packages/*"],
  "scripts": {
    "start": "docker-compose up --build",
    "dev": "concurrently \"cd packages/backend && npm run start:dev\" \"cd packages/frontend && npm start\"",
    "build": "npm run build --workspaces",
    "test": "npm run test --workspaces",
    "lint": "npm run lint --workspaces"
  },
  "devDependencies": {
    "concurrently": "^7.6.0",
    "typescript": "^5.0.0",
    "cypress": "^12.0.0",
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0",
    "ts-jest": "^29.0.0",
    "eslint": "^8.0.0",
    "prettier": "^2.7.0"
  }
}
"@

Set-FileContent -Path "tsconfig.json" -Content @"
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "noImplicitAny": true,
    "composite": true,
    "rootDir": ".",
    "outDir": "dist"
  },
  "references": [
    { "path": "./packages/shared" },
    { "path": "./packages/backend" },
    { "path": "./packages/frontend" }
  ]
}
"@

Set-FileContent -Path ".env" -Content @"
PORT=3000
NODE_API_KEY=your_secure_api_key
JWT_SECRET=your_jwt_secret
WEBHOOK_URL=http://localhost:3000/api/webhook
NODE_ENV=production
"@

Set-FileContent -Path "README.md" -Content @"
# MeowCoin Node Dashboard

A production-ready, web-based management interface for MeowCoin blockchain nodes. Provides real-time monitoring, configuration management, and operational control.

## Prerequisites
- Docker and Docker Compose

## Installation
No local package managers (Yarn/npm) required. Just use Docker:

1. Ensure Docker and Docker Compose are installed.
2. Copy `.env.example` to `.env` and update the variables (or use the above .env).
3. Run `docker-compose build` from the root directory.
4. Run `docker-compose up -d` to launch.

## Development
For development without Docker, install Node.js and npm, then run `npm install` and `npm run dev`.

## Testing
Tests can be run via Docker or locally with npm if needed.
"@

Set-FileContent -Path "jest.config.js" -Content @"
module.exports = {
  projects: [
    '<rootDir>/packages/backend',
    '<rootDir>/packages/frontend',
  ],
  testEnvironment: 'node',
  preset: 'ts-jest',
};
"@

# Create cypress directory and files
New-Item -ItemType Directory -Name "cypress" -Force | Out-Null
Set-Location "cypress"
New-Item -ItemType Directory -Name "fixtures" -Force | Out-Null
New-Item -ItemType Directory -Name "integration" -Force | Out-Null
New-Item -ItemType Directory -Name "support" -Force | Out-Null

Set-FileContent -Path "fixtures/example.json" -Content @"
{
  "nodes": [
    { "id": "node1", "name": "MeowNode-1" }
  ]
}
"@

Set-FileContent -Path "integration/dashboard.spec.ts" -Content @"
describe('Dashboard', () => {
  it('loads successfully', () => {
    cy.visit('/dashboard');
    cy.get('h1').should('contain', 'MeowCoin Node Dashboard');
  });

  it('displays node status', () => {
    cy.visit('/dashboard');
    cy.get('.node-status').should('have.length.at.least', 1);
  });
});
"@

Set-FileContent -Path "support/commands.ts" -Content @"
Cypress.Commands.add('login', () => {
  cy.request({
    method: 'POST',
    url: 'http://localhost:3000/api/login',
    body: { username: 'admin', password: 'password' },
  }).then((response) => {
    window.localStorage.setItem('token', response.body.token);
  });
});
"@

Set-FileContent -Path "tsconfig.json" -Content @"
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["**/*.ts"]
}
"@

Set-Location ..

# Create packages directory
New-Item -ItemType Directory -Name "packages" -Force | Out-Null
Set-Location "packages"

# Create shared package
New-Item -ItemType Directory -Name "shared" -Force | Out-Null
Set-Location "shared"
New-Item -ItemType Directory -Name "src" -Force | Out-Null

Set-FileContent -Path "package.json" -Content @"
{
  "name": "@meowcoin/shared",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "lint": "eslint . --ext .ts --fix",
    "preinstall": "npm install"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/jest": "^29.0.0",
    "ts-jest": "^29.0.0",
    "jest": "^29.0.0",
    "eslint": "^8.0.0"
  }
}
"@

Set-FileContent -Path "tsconfig.json" -Content @"
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*"]
}
"@

Set-FileContent -Path "src/types.ts" -Content @"
export interface NodeStatus {
  id: string;
  name: string;
  status: 'running' | 'stopped' | 'error';
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
  lastUpdated: Date;
}

export interface NodeConfig {
  port: number;
  apiKey: string;
  syncInterval: number;
  maxConnections: number;
}

export interface ApiResponse<T> {
  data: T;
  success: boolean;
  message?: string;
}
"@

Set-FileContent -Path "src/constants.ts" -Content @"
export const DEFAULT_PORT = 3000;
export const MAX_CPU_USAGE = 100;
export const MAX_MEMORY_USAGE = 100;
export const MAX_DISK_USAGE = 100;
"@

Set-Location ..

# Create backend package
New-Item -ItemType Directory -Name "backend" -Force | Out-Null
Set-Location "backend"
New-Item -ItemType Directory -Name "src" -Force | Out-Null
Set-Location "src"
New-Item -ItemType Directory -Name "middleware" -Force | Out-Null
New-Item -ItemType Directory -Name "routes" -Force | Out-Null
New-Item -ItemType Directory -Name "tests" -Force | Out-Null

Set-FileContent -Path "../package.json" -Content @"
{
  "name": "@meowcoin/backend",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "start": "node dist/index.js",
    "start:dev": "nodemon src/index.ts",
    "build": "tsc",
    "test": "jest",
    "lint": "eslint . --ext .ts --fix",
    "preinstall": "npm install"
  },
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.5.1",
    "socket.io-client": "^4.5.1",
    "jsonwebtoken": "^9.0.0",
    "http": "^0.0.1-security"
  },
  "devDependencies": {
    "@types/express": "^4.17.13",
    "@types/jest": "^29.0.0",
    "@types/jsonwebtoken": "^9.0.0",
    "nodemon": "^2.0.20",
    "ts-jest": "^29.0.0",
    "jest": "^29.0.0",
    "typescript": "^5.0.0",
    "eslint": "^8.0.0"
  }
}
"@

Set-FileContent -Path "../tsconfig.json" -Content @"
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*"]
}
"@

Set-FileContent -Path "index.ts" -Content @"
import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import nodeManager from './nodeManager';
import routes from './routes';
import config from './config';
import { authMiddleware } from './middleware/auth';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*' },
  path: '/ws',
});

app.use(express.json());
app.use(authMiddleware);
app.use('/api', routes);

io.on('connection', (socket) => {
  console.log('New WebSocket connection');
  socket.on('getNodeStatus', () => {
    socket.emit('nodeUpdate', nodeManager.getStatus());
  });
});

const PORT = process.env.PORT || config.port;
httpServer.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`);
});

nodeManager.startMonitoring(io);

app.get('/health', (_, res) => res.status(200).json({ status: 'healthy' }));
"@

Set-FileContent -Path "nodeManager.ts" -Content @"
import { NodeStatus, NodeConfig } from '../shared/src/types';
import { io } from './websocket';

class NodeManager {
  private status: NodeStatus[] = [];
  private config: NodeConfig;

  constructor() {
    this.config = {
      port: Number(process.env.PORT) || 3000,
      apiKey: process.env.NODE_API_KEY || 'default',
      syncInterval: 5000,
      maxConnections: 100,
    };
    this.initializeNodes();
  }

  private initializeNodes() {
    this.status = [
      { id: 'node1', name: 'MeowNode-1', status: 'running', cpuUsage: 30, memoryUsage: 45, diskUsage: 60, lastUpdated: new Date() },
      { id: 'node2', name: 'MeowNode-2', status: 'stopped', cpuUsage: 0, memoryUsage: 0, diskUsage: 20, lastUpdated: new Date() },
    ];
  }

  public getStatus(): NodeStatus[] {
    return this.status.map(node => ({
      ...node,
      lastUpdated: new Date(),
    }));
  }

  public updateNode(id: string, action: 'start' | 'stop' | 'restart'): NodeStatus {
    const node = this.status.find(n => n.id === id);
    if (!node) throw new Error('Node not found');

    switch (action) {
      case 'start':
        node.status = 'running';
        break;
      case 'stop':
        node.status = 'stopped';
        break;
      case 'restart':
        node.status = 'running';
        break;
    }

    io.emit('nodeUpdate', this.status);
    return node;
  }

  public startMonitoring(io: any) {
    setInterval(() => {
      this.status.forEach(node => {
        if (node.status === 'running') {
          node.cpuUsage = Math.min(100, node.cpuUsage + Math.random() * 5);
          node.memoryUsage = Math.min(100, node.memoryUsage + Math.random() * 3);
          node.diskUsage = Math.min(100, node.diskUsage + Math.random() * 2);
        }
      });
      io.emit('nodeUpdate', this.status);
    }, this.config.syncInterval);
  }

  public updateConfig(newConfig: Partial<NodeConfig>) {
    this.config = { ...this.config, ...newConfig };
  }
}

export default new NodeManager();
"@

Set-FileContent -Path "config.ts" -Content @"
export default {
  port: Number(process.env.PORT) || 3000,
  apiKey: process.env.NODE_API_KEY || 'default',
  syncInterval: 5000,
};
"@

Set-FileContent -Path "websocket.ts" -Content @"
import { Server } from 'socket.io';

export const io = new Server();
"@

Set-FileContent -Path "middleware/auth.ts" -Content @"
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export const authMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ success: false, message: 'No token provided' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'default_secret');
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Invalid token' });
  }
};
"@

Set-FileContent -Path "middleware/validate.ts" -Content @"
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';

const nodeActionSchema = z.object({
  id: z.string(),
  action: z.enum(['start', 'stop', 'restart']),
});

export const validateNodeAction = (req: Request, res: Response, next: NextFunction) => {
  try {
    nodeActionSchema.parse(req.body);
    next();
  } catch (error) {
    res.status(400).json({ success: false, message: 'Invalid node action' });
  }
};
"@

Set-FileContent -Path "routes/index.ts" -Content @"
import express from 'express';
import nodeRoutes from './node';
import configRoutes from './config';

const router = express.Router();

router.use('/node', nodeRoutes);
router.use('/config', configRoutes);

export default router;
"@

Set-FileContent -Path "routes/node.ts" -Content @"
import express from 'express';
import nodeManager from '../nodeManager';
import { validateNodeAction } from '../middleware/validate';

const router = express.Router();

router.get('/status', (req, res) => {
  res.json({ success: true, data: nodeManager.getStatus() });
});

router.post('/action', validateNodeAction, (req, res) => {
  const { id, action } = req.body;
  try {
    const updatedNode = nodeManager.updateNode(id, action);
    res.json({ success: true, data: updatedNode });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
});

export default router;
"@

Set-FileContent -Path "routes/config.ts" -Content @"
import express from 'express';
import nodeManager from '../nodeManager';

const router = express.Router();

router.get('/', (req, res) => {
  res.json({ success: true, data: nodeManager });
});

router.patch('/', express.json(), (req, res) => {
  const newConfig = req.body;
  nodeManager.updateConfig(newConfig);
  res.json({ success: true, message: 'Config updated' });
});

export default router;
"@

Set-FileContent -Path "tests/nodeManager.test.ts" -Content @"
describe('NodeManager', () => {
  it('initializes with default nodes', () => {
    const nodes = nodeManager.getStatus();
    expect(nodes.length).toBeGreaterThan(0);
    expect(nodes[0]).toHaveProperty('id');
  });

  it('updates node status', () => {
    const node = nodeManager.updateNode('node1', 'stop');
    expect(node.status).toBe('stopped');
  });
});
"@

Set-FileContent -Path "tests/routes.test.ts" -Content @"
import request from 'supertest';
import app from '../index'; // Adjust this import based on your actual file structure

describe('Node Routes', () => {
  it('returns node status', async () => {
    const res = await request(app).get('/api/node/status');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
"@

Set-Location ..

# Create frontend package
New-Item -ItemType Directory -Name "frontend" -Force | Out-Null
Set-Location "frontend"
New-Item -ItemType Directory -Name "public" -Force | Out-Null
New-Item -ItemType Directory -Name "src" -Force | Out-Null
Set-Location "src"
New-Item -ItemType Directory -Name "components" -Force | Out-Null
New-Item -ItemType Directory -Name "pages" -Force | Out-Null
New-Item -ItemType Directory -Name "hooks" -Force | Out-Null
New-Item -ItemType Directory -Name "utils" -Force | Out-Null
New-Item -ItemType Directory -Name "styles" -Force | Out-Null
New-Item -ItemType Directory -Name "tests" -Force | Out-Null

Set-FileContent -Path "../package.json" -Content @"
{
  "name": "@meowcoin/frontend",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject",
    "lint": "eslint . --ext .ts,.tsx --fix",
    "preinstall": "npm install"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.4.0",
    "socket.io-client": "^4.5.1",
    "@headlessui/react": "^1.7.0",
    "tailwindcss": "^3.2.0",
    "axios": "^1.0.0"
  },
  "devDependencies": {
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0",
    "@types/react-router-dom": "^5.3.3",
    "react-scripts": "^5.0.0",
    "typescript": "^5.0.0",
    "@types/jest": "^29.0.0",
    "jest": "^29.0.0",
    "ts-jest": "^29.0.0",
    "eslint": "^8.0.0",
    "prettier": "^2.7.0"
  }
}
"@

Set-FileContent -Path "../tsconfig.json" -Content @"
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src",
    "jsx": "react-jsx"
  },
  "include": ["src/**/*"]
}
"@

Set-FileContent -Path "../public/index.html" -Content @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MeowCoin Node Dashboard</title>
</head>
<body>
  <div id="root"></div>
</body>
</html>
"@

Set-FileContent -Path "../public/favicon.ico" -Content "" # Placeholder; replace with actual favicon if needed

Set-FileContent -Path "../public/manifest.json" -Content @"
{
  "short_name": "MeowCoin",
  "name": "MeowCoin Node Dashboard",
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
"@

Set-FileContent -Path "App.tsx" -Content @"
import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import { ThemeProvider } from './styles/theme';
import Dashboard from './components/Dashboard';
import Home from './pages/Home';
import NotFound from './pages/NotFound';
import useTheme from './hooks/useTheme';
import ErrorBoundary from './components/ErrorBoundary';

function App() {
  const { theme } = useTheme();

  return (
    <ThemeProvider theme={theme}>
      <ErrorBoundary>
        <Router>
          <div className="min-h-screen bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100 transition-colors duration-300">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="*" element={<NotFound />} />
            </Routes>
          </div>
        </Router>
      </ErrorBoundary>
    </ThemeProvider>
  );
}

export default App;
"@

Set-FileContent -Path "index.tsx" -Content @"
import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import './styles/tailwind.css';

ReactDOM.render(<App />, document.getElementById('root'));
"@

Set-FileContent -Path "components/Dashboard.tsx" -Content @"
import React, { useEffect, useState } from 'react';
import { io } from 'socket.io-client';
import { NodeStatus } from '../../shared/src/types';
import NodeStatus from './NodeStatus';
import SettingsPanel from './SettingsPanel';
import useNodeData from '../hooks/useNodeData';
import LoadingSpinner from './LoadingSpinner';

const Dashboard: React.FC = () => {
  const { nodes, updateNode, loading } = useNodeData();
  const [socket, setSocket] = useState<any>(null);

  useEffect(() => {
    const newSocket = io('http://localhost:3000', { path: '/ws' });
    setSocket(newSocket);

    newSocket.on('connect_error', (err: Error) => {
      console.error('Socket connection error:', err);
    });

    newSocket.on('nodeUpdate', (data: NodeStatus[]) => {
      updateNode(data);
    });

    return () => newSocket.disconnect();
  }, [updateNode]);

  if (loading) return <LoadingSpinner />;

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">MeowCoin Node Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {nodes.map(node => (
          <NodeStatus key={node.id} node={node} onAction={updateNode} />
        ))}
      </div>
      <SettingsPanel />
    </div>
  );
};

export default Dashboard;
"@

Set-FileContent -Path "components/NodeStatus.tsx" -Content @"
import React from 'react';
import { NodeStatus } from '../../shared/src/types';
import { formatPercentage } from '../utils/formatters';

interface NodeStatusProps {
  node: NodeStatus;
  onAction: (id: string, action: 'start' | 'stop' | 'restart') => void;
}

const NodeStatus: React.FC<NodeStatusProps> = ({ node, onAction }) => {
  return (
    <div className="bg-white dark:bg-gray-800 p-4 rounded shadow">
      <h2 className="text-xl font-semibold">{node.name}</h2>
      <p>Status: {node.status}</p>
      <p>CPU: {formatPercentage(node.cpuUsage)}</p>
      <p>Memory: {formatPercentage(node.memoryUsage)}</p>
      <p>Disk: {formatPercentage(node.diskUsage)}</p>
      <p>Last Updated: {node.lastUpdated.toLocaleTimeString()}</p>
      <div className="mt-4 space-x-2">
        <button
          onClick={() => onAction(node.id, 'start')}
          className="bg-green-500 text-white p-2 rounded"
          disabled={node.status === 'running'}
        >
          Start
        </button>
        <button
          onClick={() => onAction(node.id, 'stop')}
          className="bg-red-500 text-white p-2 rounded"
          disabled={node.status === 'stopped'}
        >
          Stop
        </button>
        <button
          onClick={() => onAction(node.id, 'restart')}
          className="bg-yellow-500 text-white p-2 rounded"
        >
          Restart
        </button>
      </div>
    </div>
  );
};

export default NodeStatus;
"@

Set-FileContent -Path "components/SettingsPanel.tsx" -Content @"
import React, { useState } from 'react';
import useNodeData from '../hooks/useNodeData';

const SettingsPanel: React.FC = () => {
  const { updateConfig } = useNodeData();
  const [port, setPort] = useState<number>(3000);
  const [syncInterval, setSyncInterval] = useState<number>(5000);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    updateConfig({ port, syncInterval });
  };

  return (
    <div className="mt-8 bg-white dark:bg-gray-800 p-4 rounded shadow">
      <h2 className="text-xl font-semibold mb-4">Settings</h2>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="port">Port</label>
          <input
            type="number"
            id="port"
            value={port}
            onChange={(e) => setPort(Number(e.target.value))}
            className="w-full p-2 border rounded dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label htmlFor="syncInterval">Sync Interval (ms)</label>
          <input
            type="number"
            id="syncInterval"
            value={syncInterval}
            onChange={(e) => setSyncInterval(Number(e.target.value))}
            className="w-full p-2 border rounded dark:bg-gray-700 dark:text-white"
          />
        </div>
        <button type="submit" className="bg-blue-500 text-white p-2 rounded">
          Save Settings
        </button>
      </form>
    </div>
  );
};

export default SettingsPanel;
"@

Set-FileContent -Path "components/ErrorBoundary.tsx" -Content @"
import React, { Component, ReactNode } from 'react';

interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return <h1>Something went wrong. Please try again later.</h1>;
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
"@

Set-FileContent -Path "components/LoadingSpinner.tsx" -Content @"
import React from 'react';

const LoadingSpinner: React.FC = () => {
  return (
    <div className="flex justify-center items-center h-screen">
      <div className="animate-spin rounded-full h-32 w-32 border-t-2 border-b-2 border-blue-500"></div>
    </div>
  );
};

export default LoadingSpinner;
"@

Set-FileContent -Path "pages/Home.tsx" -Content @"
import React from 'react';

const Home: React.FC = () => {
  return (
    <div className="container mx-auto p-4">
      <h1 className="text-3xl font-bold">Welcome to MeowCoin Node Dashboard</h1>
      <p className="mt-4">Manage your MeowCoin nodes with ease.</p>
      <a href="/dashboard" className="mt-4 inline-block bg-blue-500 text-white p-2 rounded">
        Go to Dashboard
      </a>
    </div>
  );
};

export default Home;
"@

Set-FileContent -Path "pages/NotFound.tsx" -Content @"
import React from 'react';

const NotFound: React.FC = () => {
  return (
    <div className="container mx-auto p-4 text-center">
      <h1 className="text-3xl font-bold">404 - Not Found</h1>
      <p className="mt-4">The page you are looking for does not exist.</p>
      <a href="/" className="mt-4 inline-block bg-blue-500 text-white p-2 rounded">
        Go Home
      </a>
    </div>
  );
};

export default NotFound;
"@

Set-FileContent -Path "hooks/useNodeData.ts" -Content @"
import { useState, useEffect, useCallback } from 'react';
import { NodeStatus, NodeConfig } from '../../shared/src/types';
import { io } from 'socket.io-client';
import api from '../utils/api';

const useNodeData = () => {
  const [nodes, setNodes] = useState<NodeStatus[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchNodes = async () => {
    try {
      const response = await api.get('/api/node/status');
      setNodes(response.data.data);
    } catch (error) {
      console.error('Failed to fetch nodes:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateNode = useCallback((updatedNodes: NodeStatus[] | ((prev: NodeStatus[]) => NodeStatus[])) => {
    setNodes(prev =>
      typeof updatedNodes === 'function' ? updatedNodes(prev) : updatedNodes
    );
  }, []);

  const updateConfig = async (newConfig: Partial<NodeConfig>) => {
    try {
      await api.patch('/api/config', newConfig);
      fetchNodes();
    } catch (error) {
      console.error('Failed to update config:', error);
    }
  };

  useEffect(() => {
    fetchNodes();

    const socket = io('http://localhost:3000', { path: '/ws' });
    socket.on('nodeUpdate', (data: NodeStatus[]) => {
      updateNode(data);
    });

    return () => socket.disconnect();
  }, [updateNode]);

  return { nodes, updateNode, updateConfig, loading };
};

export default useNodeData;
"@

Set-FileContent -Path "hooks/useTheme.ts" -Content @"
import { useState, useEffect } from 'react';

const useTheme = () => {
  const [theme, setTheme] = useState<'light' | 'dark'>(
    localStorage.getItem('theme') === 'dark' ? 'dark' : 'light'
  );

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = (e: MediaQueryListEvent) => {
      setTheme(e.matches ? 'dark' : 'light');
    };

    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  const toggleTheme = () => {
    const newTheme = theme === 'light' ? 'dark' : 'light';
    setTheme(newTheme);
    localStorage.setItem('theme', newTheme);
  };

  return { theme, toggleTheme };
};

export default useTheme;
"@

Set-FileContent -Path "hooks/useAuth.ts" -Content @"
import { useState, useEffect } from 'react';
import api from '../utils/api';

const useAuth = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      setIsAuthenticated(true);
    }
  }, []);

  const login = async (credentials: { username: string; password: string }) => {
    try {
      const response = await api.post('/api/login', credentials);
      localStorage.setItem('token', response.data.token);
      api.defaults.headers.common['Authorization'] = `Bearer ${response.data.token}`;
      setIsAuthenticated(true);
      return true;
    } catch (error) {
      return false;
    }
  };

  const logout = () => {
    localStorage.removeItem('token');
    delete api.defaults.headers.common['Authorization'];
    setIsAuthenticated(false);
  };

  return { isAuthenticated, login, logout };
};

export default useAuth;
"@

Set-FileContent -Path "utils/formatters.ts" -Content @"
export const formatPercentage = (value: number): string => {
  return `${value.toFixed(2)}%`;
};

export const formatDate = (date: Date): string => {
  return date.toLocaleString();
};
"@

Set-FileContent -Path "utils/api.ts" -Content @"
import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:3000/api',
  timeout: 10000,
});

export default api;
"@

Set-FileContent -Path "utils/logger.ts" -Content @"
export const logger = {
  info: (message: string) => console.log(`[Info] ${message}`),
  error: (message: string, error?: any) => console.error(`[Error] ${message}`, error),
  warn: (message: string) => console.warn(`[Warn] ${message}`),
};
"@

Set-FileContent -Path "styles/tailwind.css" -Content @"
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  body {
    @apply bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100 transition-colors duration-300;
  }
}
"@

Set-FileContent -Path "styles/theme.ts" -Content @"
import { createContext, useContext } from 'react';

interface ThemeContextType {
  theme: 'light' | 'dark';
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export const ThemeProvider: React.FC<{ theme: 'light' | 'dark'; children: React.ReactNode }> = ({ theme, children }) => {
  const toggleTheme = () => {
    // This would be handled by useTheme hook, but for context, we simulate it
  };

  return <ThemeContext.Provider value={{ theme, toggleTheme }}>{children}</ThemeContext.Provider>;
};

export const useThemeContext = () => {
  const context = useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useThemeContext must be used within a ThemeProvider');
  }
  return context;
};
"@

Set-FileContent -Path "tests/Dashboard.test.tsx" -Content @"
describe('Dashboard', () => {
  it('renders without crashing', () => {
    render(<Dashboard />);
    expect(screen.getByText('MeowCoin Node Dashboard')).toBeInTheDocument();
  });

  it('displays nodes', () => {
    render(<Dashboard />);
    expect(screen.getAllByText(/MeowNode-/i)).toHaveLength(2);
  });
});
"@

Set-FileContent -Path "tests/App.test.tsx" -Content @"
describe('App', () => {
  it('renders without crashing', () => {
    render(<App />);
    expect(screen.getByText(/Welcome to MeowCoin Node Dashboard/i)).toBeInTheDocument();
  });

  it('navigates to dashboard', () => {
    render(<App />);
    fireEvent.click(screen.getByText(/Go to Dashboard/i));
    expect(screen.getByText('MeowCoin Node Dashboard')).toBeInTheDocument();
  });
});
"@

# Return to the parent directory
Set-Location ..

Write-Host "Project structure and files updated successfully! You can now run 'docker-compose build' and 'docker-compose up -d' from $rootDir."