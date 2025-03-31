# Build stage for shared types module
FROM node:16-alpine AS shared-builder
WORKDIR /app/shared

# Copy shared module files
COPY shared/package*.json ./
COPY shared/tsconfig.json ./
COPY shared/src ./src

# Install dependencies and build
RUN npm install
RUN npm run build

# Build stage for frontend
FROM node:16-alpine AS frontend-builder
WORKDIR /app/frontend

# Create a basic frontend file structure
RUN mkdir -p dist
WORKDIR /app/frontend/dist

# Create index.html - breaking it into smaller, simpler echo commands
RUN echo '<!DOCTYPE html>' > index.html && \
    echo '<html>' >> index.html && \
    echo '<head>' >> index.html && \
    echo '    <title>Meowcoin Dashboard</title>' >> index.html && \
    echo '    <style>' >> index.html && \
    echo '        body { font-family: Arial, sans-serif; max-width: 1000px; margin: 0 auto; padding: 20px; background-color: #f5f7fa; }' >> index.html && \
    echo '        .card { border: 1px solid #e1e4e8; border-radius: 8px; padding: 20px; margin-bottom: 20px; background-color: white; box-shadow: 0 2px 6px rgba(0,0,0,0.05); }' >> index.html && \
    echo '        .status { display: inline-block; padding: 5px 10px; border-radius: 5px; color: white; font-weight: bold; }' >> index.html && \
    echo '        .running { background-color: #28a745; }' >> index.html && \
    echo '        .syncing { background-color: #ffc107; }' >> index.html && \
    echo '        .stopped, .no_connections { background-color: #dc3545; }' >> index.html && \
    echo '        .progress-bar { height: 8px; background-color: #e9ecef; border-radius: 4px; margin: 10px 0; overflow: hidden; }' >> index.html && \
    echo '        .progress { height: 100%; background-color: #4e73df; transition: width 0.3s; }' >> index.html && \
    echo '        .progress-mem { background-color: #2ecc71; }' >> index.html && \
    echo '        .progress-disk { background-color: #3498db; }' >> index.html && \
    echo '        .progress-warn { background-color: #f39c12; }' >> index.html && \
    echo '        .progress-danger { background-color: #e74c3c; }' >> index.html && \
    echo '        .updated { text-align: right; color: #6c757d; font-size: 12px; margin-top: 5px; }' >> index.html && \
    echo '        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 20px; }' >> index.html && \
    echo '        .error-message { display: none; color: #dc3545; margin-top: 5px; }' >> index.html && \
    echo '        h2 { margin-top: 0; color: #2c3e50; }' >> index.html && \
    echo '        a { color: #3498db; text-decoration: none; }' >> index.html && \
    echo '        a:hover { text-decoration: underline; }' >> index.html && \
    echo '    </style>' >> index.html

RUN echo '    <script>' >> index.html && \
    echo '        let dashboard = {' >> index.html && \
    echo '            status: "stopped",' >> index.html && \
    echo '            version: "Unknown",' >> index.html && \
    echo '            connections: 0,' >> index.html && \
    echo '            blocks: 0,' >> index.html && \
    echo '            headers: 0,' >> index.html && \
    echo '            progress: "0.00",' >> index.html && \
    echo '            memoryPercent: 0,' >> index.html && \
    echo '            memoryUsed: 0,' >> index.html && \
    echo '            memoryTotal: 0,' >> index.html && \
    echo '            diskPercent: 0,' >> index.html && \
    echo '            diskUsed: "0G",' >> index.html && \
    echo '            diskTotal: "0G",' >> index.html && \
    echo '            lastUpdated: new Date().toLocaleString()' >> index.html && \
    echo '        };' >> index.html

RUN echo '        function updateUI() {' >> index.html && \
    echo '            document.getElementById("node-status").textContent = dashboard.status.charAt(0).toUpperCase() + dashboard.status.slice(1);' >> index.html && \
    echo '            document.getElementById("node-status").className = "status " + dashboard.status;' >> index.html && \
    echo '            document.getElementById("node-version").textContent = dashboard.version;' >> index.html && \
    echo '            document.getElementById("node-connections").textContent = dashboard.connections;' >> index.html && \
    echo '            document.getElementById("blockchain-blocks").textContent = dashboard.blocks.toLocaleString();' >> index.html && \
    echo '            document.getElementById("blockchain-headers").textContent = dashboard.headers.toLocaleString();' >> index.html && \
    echo '            document.getElementById("blockchain-progress").style.width = dashboard.progress + "%";' >> index.html && \
    echo '            document.getElementById("blockchain-progress-text").textContent = dashboard.progress + "%";' >> index.html && \
    echo '            document.getElementById("memory-bar").style.width = dashboard.memoryPercent + "%";' >> index.html && \
    echo '            document.getElementById("memory-bar").className = "progress progress-mem" + (dashboard.memoryPercent > 80 ? " progress-danger" : dashboard.memoryPercent > 60 ? " progress-warn" : "");' >> index.html && \
    echo '            document.getElementById("memory-percent").textContent = dashboard.memoryPercent + "%";' >> index.html && \
    echo '            document.getElementById("memory-details").textContent = dashboard.memoryUsed + "MB / " + dashboard.memoryTotal + "MB";' >> index.html && \
    echo '            document.getElementById("disk-bar").style.width = dashboard.diskPercent + "%";' >> index.html && \
    echo '            document.getElementById("disk-bar").className = "progress progress-disk" + (dashboard.diskPercent > 80 ? " progress-danger" : dashboard.diskPercent > 60 ? " progress-warn" : "");' >> index.html && \
    echo '            document.getElementById("disk-percent").textContent = dashboard.diskPercent + "%";' >> index.html && \
    echo '            document.getElementById("disk-details").textContent = dashboard.diskUsed + " / " + dashboard.diskTotal;' >> index.html && \
    echo '            document.getElementById("last-updated").textContent = dashboard.lastUpdated;' >> index.html && \
    echo '            document.getElementById("error-message").style.display = "none";' >> index.html && \
    echo '        }' >> index.html

RUN echo '        function fetchData() {' >> index.html && \
    echo '            fetch("/api/status")' >> index.html && \
    echo '                .then(response => {' >> index.html && \
    echo '                    if (!response.ok) {' >> index.html && \
    echo '                        throw new Error("API response was not ok");' >> index.html && \
    echo '                    }' >> index.html && \
    echo '                    return response.json();' >> index.html && \
    echo '                })' >> index.html && \
    echo '                .then(data => {' >> index.html && \
    echo '                    dashboard.status = data.status || "stopped";' >> index.html && \
    echo '                    dashboard.version = data.node.version || "Unknown";' >> index.html && \
    echo '                    dashboard.connections = data.node.connections || 0;' >> index.html && \
    echo '                    dashboard.blocks = data.blockchain.blocks || 0;' >> index.html && \
    echo '                    dashboard.headers = data.blockchain.headers || 0;' >> index.html && \
    echo '                    dashboard.progress = data.blockchain.progress || "0.00";' >> index.html && \
    echo '                    dashboard.memoryPercent = parseFloat(data.system.memory.percent) || 0;' >> index.html && \
    echo '                    dashboard.memoryUsed = data.system.memory.used || 0;' >> index.html && \
    echo '                    dashboard.memoryTotal = data.system.memory.total || 0;' >> index.html && \
    echo '                    dashboard.diskPercent = data.system.disk.percent || 0;' >> index.html && \
    echo '                    dashboard.diskUsed = data.system.disk.used || "0G";' >> index.html && \
    echo '                    dashboard.diskTotal = data.system.disk.size || "0G";' >> index.html && \
    echo '                    dashboard.lastUpdated = new Date().toLocaleString();' >> index.html && \
    echo '                    updateUI();' >> index.html && \
    echo '                })' >> index.html && \
    echo '                .catch(error => {' >> index.html && \
    echo '                    console.error("Error fetching dashboard data:", error);' >> index.html && \
    echo '                    document.getElementById("error-message").style.display = "block";' >> index.html && \
    echo '                    document.getElementById("error-message").textContent = "Error updating dashboard: " + error.message;' >> index.html && \
    echo '                });' >> index.html && \
    echo '        }' >> index.html

RUN echo '        document.addEventListener("DOMContentLoaded", function() {' >> index.html && \
    echo '            updateUI();' >> index.html && \
    echo '            fetchData();' >> index.html && \
    echo '            setInterval(fetchData, 5000);' >> index.html && \
    echo '        });' >> index.html && \
    echo '    </script>' >> index.html && \
    echo '</head>' >> index.html

RUN echo '<body>' >> index.html && \
    echo '    <h1>Meowcoin Node Dashboard</h1>' >> index.html && \
    echo '    <div id="error-message" class="error-message"></div>' >> index.html && \
    echo '    <div class="card">' >> index.html && \
    echo '        <h2>Node Status</h2>' >> index.html && \
    echo '        <p>Status: <span id="node-status" class="status">Stopped</span></p>' >> index.html && \
    echo '        <p>Version: <span id="node-version">Unknown</span></p>' >> index.html && \
    echo '        <p>Connections: <span id="node-connections">0</span></p>' >> index.html && \
    echo '    </div>' >> index.html

RUN echo '    <div class="card">' >> index.html && \
    echo '        <h2>Blockchain Info</h2>' >> index.html && \
    echo '        <p>Blocks: <span id="blockchain-blocks">0</span></p>' >> index.html && \
    echo '        <p>Headers: <span id="blockchain-headers">0</span></p>' >> index.html && \
    echo '        <p>Sync Progress:</p>' >> index.html && \
    echo '        <div class="progress-bar">' >> index.html && \
    echo '            <div id="blockchain-progress" class="progress" style="width:0%"></div>' >> index.html && \
    echo '        </div>' >> index.html && \
    echo '        <p id="blockchain-progress-text">0.00%</p>' >> index.html && \
    echo '    </div>' >> index.html

RUN echo '    <div class="card">' >> index.html && \
    echo '        <h2>System Resources</h2>' >> index.html && \
    echo '        <div class="grid">' >> index.html && \
    echo '            <div>' >> index.html && \
    echo '                <h3>Memory Usage</h3>' >> index.html && \
    echo '                <div class="progress-bar">' >> index.html && \
    echo '                    <div id="memory-bar" class="progress progress-mem" style="width:0%"></div>' >> index.html && \
    echo '                </div>' >> index.html && \
    echo '                <p id="memory-percent">0%</p>' >> index.html && \
    echo '                <p id="memory-details">0MB / 0MB</p>' >> index.html && \
    echo '            </div>' >> index.html && \
    echo '            <div>' >> index.html && \
    echo '                <h3>Disk Usage</h3>' >> index.html && \
    echo '                <div class="progress-bar">' >> index.html && \
    echo '                    <div id="disk-bar" class="progress progress-disk" style="width:0%"></div>' >> index.html && \
    echo '                </div>' >> index.html && \
    echo '                <p id="disk-percent">0%</p>' >> index.html && \
    echo '                <p id="disk-details">0GB / 0GB</p>' >> index.html && \
    echo '            </div>' >> index.html && \
    echo '        </div>' >> index.html && \
    echo '    </div>' >> index.html

RUN echo '    <div class="card">' >> index.html && \
    echo '        <h2>API Endpoints</h2>' >> index.html && \
    echo '        <p><a href="/api/status">/api/status</a> - Get node status information</p>' >> index.html && \
    echo '    </div>' >> index.html && \
    echo '    <footer>' >> index.html && \
    echo '        <p>Meowcoin Node Dashboard © 2025</p>' >> index.html && \
    echo '        <div class="updated">Last updated: <span id="last-updated"></span></div>' >> index.html && \
    echo '    </footer>' >> index.html && \
    echo '</body>' >> index.html && \
    echo '</html>' >> index.html

# Build stage for backend
FROM node:16-alpine AS backend-builder
WORKDIR /app/backend

# Copy package files and install dependencies
COPY backend/package*.json ./
RUN npm install

# Create backend directory structure
RUN mkdir -p src/types src/services src/controllers src/routes src/config

# Create types/index.ts - breaking into smaller parts
WORKDIR /app/backend/src/types
RUN echo 'export interface NodeStatus {' > index.ts && \
    echo '  status: "running" | "syncing" | "stopped" | "no_connections" | "starting";' >> index.ts && \
    echo '  blockchain: {' >> index.ts && \
    echo '    blocks: number;' >> index.ts && \
    echo '    headers: number;' >> index.ts && \
    echo '    progress: string;' >> index.ts && \
    echo '  };' >> index.ts && \
    echo '  node: {' >> index.ts && \
    echo '    version: string;' >> index.ts && \
    echo '    subversion: string;' >> index.ts && \
    echo '    connections: number;' >> index.ts && \
    echo '    bytesReceived: number;' >> index.ts && \
    echo '    bytesSent: number;' >> index.ts && \
    echo '  };' >> index.ts && \
    echo '  system: {' >> index.ts && \
    echo '    memory: {' >> index.ts && \
    echo '      used: number;' >> index.ts && \
    echo '      total: number;' >> index.ts && \
    echo '      percent: string;' >> index.ts && \
    echo '    };' >> index.ts && \
    echo '    disk: {' >> index.ts && \
    echo '      size: string;' >> index.ts && \
    echo '      used: string;' >> index.ts && \
    echo '      percent: number;' >> index.ts && \
    echo '    };' >> index.ts && \
    echo '  };' >> index.ts && \
    echo '  settings: {' >> index.ts && \
    echo '    maxConnections: number;' >> index.ts && \
    echo '    enableTxindex: number;' >> index.ts && \
    echo '  };' >> index.ts && \
    echo '  updated: string;' >> index.ts && \
    echo '  updateAvailable?: boolean;' >> index.ts && \
    echo '  latestVersion?: string;' >> index.ts && \
    echo '}' >> index.ts

RUN echo 'export interface DiskUsage {' >> index.ts && \
    echo '  success: boolean;' >> index.ts && \
    echo '  paths: {' >> index.ts && \
    echo '    path: string;' >> index.ts && \
    echo '    sizeBytes: number;' >> index.ts && \
    echo '  }[];' >> index.ts && \
    echo '}' >> index.ts && \
    echo '' >> index.ts && \
    echo 'export interface LogResponse {' >> index.ts && \
    echo '  success: boolean;' >> index.ts && \
    echo '  logs: string[];' >> index.ts && \
    echo '  timestamp: number;' >> index.ts && \
    echo '}' >> index.ts && \
    echo '' >> index.ts && \
    echo 'export interface SettingsRequest {' >> index.ts && \
    echo '  maxConnections: number;' >> index.ts && \
    echo '  enableTxindex: number;' >> index.ts && \
    echo '}' >> index.ts && \
    echo '' >> index.ts && \
    echo 'export interface NodeControlRequest {' >> index.ts && \
    echo '  action: "restart" | "shutdown";' >> index.ts && \
    echo '}' >> index.ts && \
    echo '' >> index.ts && \
    echo 'export interface UpdateRequest {' >> index.ts && \
    echo '  version: string;' >> index.ts && \
    echo '}' >> index.ts

# Create config/environment.ts
WORKDIR /app/backend/src/config
RUN echo 'export const environment = {' > environment.ts && \
    echo '  port: process.env.PORT || 8080,' >> environment.ts && \
    echo '  meowcoinConfig: process.env.MEOWCOIN_CONFIG || "/config",' >> environment.ts && \
    echo '  meowcoinData: process.env.MEOWCOIN_DATA || "/data"' >> environment.ts && \
    echo '};' >> environment.ts

# Create services/nodeService.ts - breaking into smaller parts to avoid quote issues
WORKDIR /app/backend/src/services

# Part 1: Basic imports and helper functions
RUN echo 'import { exec } from "child_process";' > nodeService.ts && \
    echo 'import { NodeStatus } from "../types";' >> nodeService.ts && \
    echo '' >> nodeService.ts && \
    echo 'const MEOWCOIN_CONFIG = process.env.MEOWCOIN_CONFIG || "/config";' >> nodeService.ts && \
    echo 'const MEOWCOIN_DATA = process.env.MEOWCOIN_DATA || "/data";' >> nodeService.ts && \
    echo '' >> nodeService.ts && \
    echo '// Execute command and handle errors gracefully' >> nodeService.ts && \
    echo 'function executeCommand(cmd: string): Promise<string> {' >> nodeService.ts && \
    echo '  return new Promise((resolve) => {' >> nodeService.ts && \
    echo '    exec(cmd, (error, stdout, stderr) => {' >> nodeService.ts && \
    echo '      if (error) {' >> nodeService.ts && \
    echo '        console.error(`Command execution error: ${error.message}`);' >> nodeService.ts && \
    echo '        return resolve("");' >> nodeService.ts && \
    echo '      }' >> nodeService.ts && \
    echo '      if (stderr) {' >> nodeService.ts && \
    echo '        console.error(`Command stderr: ${stderr}`);' >> nodeService.ts && \
    echo '      }' >> nodeService.ts && \
    echo '      return resolve(stdout.trim());' >> nodeService.ts && \
    echo '    });' >> nodeService.ts && \
    echo '  });' >> nodeService.ts && \
    echo '}' >> nodeService.ts

# Part 2: Safe parsing functions
RUN echo '// Parse number safely' >> nodeService.ts && \
    echo 'function safeParseInt(value: string, defaultValue: number = 0): number {' >> nodeService.ts && \
    echo '  const parsed = parseInt(value, 10);' >> nodeService.ts && \
    echo '  return isNaN(parsed) ? defaultValue : parsed;' >> nodeService.ts && \
    echo '}' >> nodeService.ts && \
    echo '' >> nodeService.ts && \
    echo '// Parse float safely' >> nodeService.ts && \
    echo 'function safeParseFloat(value: string, defaultValue: number = 0): number {' >> nodeService.ts && \
    echo '  const parsed = parseFloat(value);' >> nodeService.ts && \
    echo '  return isNaN(parsed) ? defaultValue : parsed;' >> nodeService.ts && \
    echo '}' >> nodeService.ts

# Part 3: Blockchain info function
RUN echo '// Get blockchain info' >> nodeService.ts && \
    echo 'async function getBlockchainInfo() {' >> nodeService.ts && \
    echo '  try {' >> nodeService.ts && \
    echo '    const cmd = `meowcoin-cli -conf=${MEOWCOIN_CONFIG}/meowcoin.conf getblockchaininfo`;' >> nodeService.ts && \
    echo '    const output = await executeCommand(cmd);' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    if (!output) {' >> nodeService.ts && \
    echo '      return { blocks: 0, headers: 0, verificationprogress: 0, initialblockdownload: false };' >> nodeService.ts && \
    echo '    }' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    return JSON.parse(output);' >> nodeService.ts && \
    echo '  } catch (error) {' >> nodeService.ts && \
    echo '    console.error("Error parsing blockchain info:", error);' >> nodeService.ts && \
    echo '    return { blocks: 0, headers: 0, verificationprogress: 0, initialblockdownload: false };' >> nodeService.ts && \
    echo '  }' >> nodeService.ts && \
    echo '}' >> nodeService.ts

# Part 4: Network info function
RUN echo '// Get network info' >> nodeService.ts && \
    echo 'async function getNetworkInfo() {' >> nodeService.ts && \
    echo '  try {' >> nodeService.ts && \
    echo '    const cmd = `meowcoin-cli -conf=${MEOWCOIN_CONFIG}/meowcoin.conf getnetworkinfo`;' >> nodeService.ts && \
    echo '    const output = await executeCommand(cmd);' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    if (!output) {' >> nodeService.ts && \
    echo '      return { version: "Unknown", subversion: "Meow-v2.0.5", connections: 0 };' >> nodeService.ts && \
    echo '    }' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    return JSON.parse(output);' >> nodeService.ts && \
    echo '  } catch (error) {' >> nodeService.ts && \
    echo '    console.error("Error parsing network info:", error);' >> nodeService.ts && \
    echo '    return { version: "Unknown", subversion: "Meow-v2.0.5", connections: 0 };' >> nodeService.ts && \
    echo '  }' >> nodeService.ts && \
    echo '}' >> nodeService.ts

# Part 5: Memory info function (escaping the single quotes carefully)
RUN echo '// Get memory info' >> nodeService.ts && \
    echo 'async function getMemoryInfo() {' >> nodeService.ts && \
    echo '  try {' >> nodeService.ts && \
    echo '    const memInfoCmd = "cat /proc/meminfo | grep -E \"MemTotal|MemAvailable\"";' >> nodeService.ts && \
    echo '    const output = await executeCommand(memInfoCmd);' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    if (!output) {' >> nodeService.ts && \
    echo '      return { total: 100, used: 50, percent: "50.0" };' >> nodeService.ts && \
    echo '    }' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    const lines = output.split("\\n");' >> nodeService.ts && \
    echo '    let total = 0;' >> nodeService.ts && \
    echo '    let available = 0;' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    for (const line of lines) {' >> nodeService.ts && \
    echo '      if (line.includes("MemTotal")) {' >> nodeService.ts && \
    echo '        const match = line.match(/\\d+/);' >> nodeService.ts && \
    echo '        if (match) {' >> nodeService.ts && \
    echo '          total = parseInt(match[0], 10);' >> nodeService.ts && \
    echo '        }' >> nodeService.ts && \
    echo '      } else if (line.includes("MemAvailable")) {' >> nodeService.ts && \
    echo '        const match = line.match(/\\d+/);' >> nodeService.ts && \
    echo '        if (match) {' >> nodeService.ts && \
    echo '          available = parseInt(match[0], 10);' >> nodeService.ts && \
    echo '        }' >> nodeService.ts && \
    echo '      }' >> nodeService.ts && \
    echo '    }' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    // Convert to MB and calculate usage' >> nodeService.ts && \
    echo '    total = Math.round(total / 1024);' >> nodeService.ts && \
    echo '    available = Math.round(available / 1024);' >> nodeService.ts && \
    echo '    const used = total - available;' >> nodeService.ts && \
    echo '    const percent = ((used / total) * 100).toFixed(1);' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    return { total, used, percent };' >> nodeService.ts && \
    echo '  } catch (error) {' >> nodeService.ts && \
    echo '    console.error("Error getting memory info:", error);' >> nodeService.ts && \
    echo '    return { total: 100, used: 50, percent: "50.0" };' >> nodeService.ts && \
    echo '  }' >> nodeService.ts && \
    echo '}' >> nodeService.ts

# Part 6: Disk info function
RUN echo '// Get disk info' >> nodeService.ts && \
    echo 'async function getDiskInfo() {' >> nodeService.ts && \
    echo '  try {' >> nodeService.ts && \
    echo '    const cmd = `df -h ${MEOWCOIN_DATA} | tail -1`;' >> nodeService.ts && \
    echo '    const output = await executeCommand(cmd);' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    if (!output) {' >> nodeService.ts && \
    echo '      return { size: "10G", used: "5G", percent: 50 };' >> nodeService.ts && \
    echo '    }' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    const parts = output.split(/\\s+/);' >> nodeService.ts && \
    echo '    if (parts.length < 5) {' >> nodeService.ts && \
    echo '      return { size: "10G", used: "5G", percent: 50 };' >> nodeService.ts && \
    echo '    }' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    const size = parts[1];' >> nodeService.ts && \
    echo '    const used = parts[2];' >> nodeService.ts && \
    echo '    const percentStr = parts[4].replace("%", "");' >> nodeService.ts && \
    echo '    const percent = parseInt(percentStr, 10);' >> nodeService.ts && \
    echo '    ' >> nodeService.ts && \
    echo '    return { size, used, percent: isNaN(percent) ? 50 : percent };' >> nodeService.ts && \
    echo '  } catch (error) {' >> nodeService.ts && \
    echo '    console.error("Error getting disk info:", error);' >> nodeService.ts && \
    echo '    return { size: "10G", used: "5G", percent: 50 };' >> nodeService.ts && \
    echo '  }' >> nodeService.ts && \
    echo '}' >> nodeService.ts

## Part 7: Main getNodeStatus function (continued)
RUN echo '      } else if (networkInfo.connections === 0) {' >> nodeService.ts && \
    echo '        status = "no_connections";' >> nodeService.ts && \
    echo '      } else {' >> nodeService.ts && \
    echo '        status = "running";' >> nodeService.ts && \
    echo '      }' >> nodeService.ts && \
    echo '    }' >> nodeService.ts && \
    echo '' >> nodeService.ts && \
    echo '    // Assemble response object' >> nodeService.ts && \
    echo '    const response: NodeStatus = {' >> nodeService.ts && \
    echo '      status,' >> nodeService.ts && \
    echo '      blockchain: {' >> nodeService.ts && \
    echo '        blocks: blockchainInfo.blocks || 0,' >> nodeService.ts && \
    echo '        headers: blockchainInfo.headers || 0,' >> nodeService.ts && \
    echo '        progress: blockchainInfo.verificationprogress ? (blockchainInfo.verificationprogress * 100).toFixed(2) : "0.00"' >> nodeService.ts && \
    echo '      },' >> nodeService.ts && \
    echo '      node: {' >> nodeService.ts && \
    echo '        version: networkInfo.subversion || "Meow-v2.0.5",' >> nodeService.ts && \
    echo '        subversion: networkInfo.subversion || "Unknown",' >> nodeService.ts && \
    echo '        connections: networkInfo.connections || 0,' >> nodeService.ts && \
    echo '        bytesReceived: 0,' >> nodeService.ts && \
    echo '        bytesSent: 0' >> nodeService.ts && \
    echo '      },' >> nodeService.ts && \
    echo '      system: {' >> nodeService.ts && \
    echo '        memory: {' >> nodeService.ts && \
    echo '          used: memInfo.used,' >> nodeService.ts && \
    echo '          total: memInfo.total,' >> nodeService.ts && \
    echo '          percent: memInfo.percent' >> nodeService.ts && \
    echo '        },' >> nodeService.ts && \
    echo '        disk: {' >> nodeService.ts && \
    echo '          size: diskInfo.size,' >> nodeService.ts && \
    echo '          used: diskInfo.used,' >> nodeService.ts && \
    echo '          percent: diskInfo.percent' >> nodeService.ts && \
    echo '        }' >> nodeService.ts && \
    echo '      },' >> nodeService.ts && \
    echo '      settings: {' >> nodeService.ts && \
    echo '        maxConnections: 50,' >> nodeService.ts && \
    echo '        enableTxindex: 1' >> nodeService.ts && \
    echo '      },' >> nodeService.ts && \
    echo '      updated: new Date().toISOString()' >> nodeService.ts && \
    echo '    };' >> nodeService.ts && \
    echo '' >> nodeService.ts && \
    echo '    return response;' >> nodeService.ts && \
    echo '  } catch (error) {' >> nodeService.ts && \
    echo '    console.error("Error in getNodeStatus:", error);' >> nodeService.ts && \
    echo '    return null;' >> nodeService.ts && \
    echo '  }' >> nodeService.ts && \
    echo '}' >> nodeService.ts

# Create controllers/nodeController.ts
WORKDIR /app/backend/src/controllers
RUN echo 'import { Request, Response } from "express";' > nodeController.ts && \
echo 'import { getNodeStatus } from "../services/nodeService";' >> nodeController.ts && \
echo '' >> nodeController.ts && \
echo 'export async function getStatus(req: Request, res: Response) {' >> nodeController.ts && \
echo '  try {' >> nodeController.ts && \
echo '    const status = await getNodeStatus();' >> nodeController.ts && \
echo '    if (!status) {' >> nodeController.ts && \
echo '      return res.status(500).json({ success: false, message: "Failed to get node status" });' >> nodeController.ts && \
echo '    }' >> nodeController.ts && \
echo '    res.json(status);' >> nodeController.ts && \
echo '  } catch (error) {' >> nodeController.ts && \
echo '    console.error("Error in getStatus controller:", error);' >> nodeController.ts && \
echo '    res.status(500).json({' >> nodeController.ts && \
echo '      success: false,' >> nodeController.ts && \
echo '      message: `Error in getStatus controller: ${error instanceof Error ? error.message : "Unknown error"}`' >> nodeController.ts && \
echo '    });' >> nodeController.ts && \
echo '  }' >> nodeController.ts && \
echo '}' >> nodeController.ts

# Create routes/nodeRoutes.ts
WORKDIR /app/backend/src/routes
RUN echo 'import { Router } from "express";' > nodeRoutes.ts && \
echo 'import { getStatus } from "../controllers/nodeController";' >> nodeRoutes.ts && \
echo '' >> nodeRoutes.ts && \
echo 'const router = Router();' >> nodeRoutes.ts && \
echo '' >> nodeRoutes.ts && \
echo 'router.get("/status", getStatus);' >> nodeRoutes.ts && \
echo '' >> nodeRoutes.ts && \
echo 'export default router;' >> nodeRoutes.ts

# Create src/index.ts (main entry point)
WORKDIR /app/backend/src
RUN echo 'import express from "express";' > index.ts && \
echo 'import http from "http";' >> index.ts && \
echo 'import { Server } from "socket.io";' >> index.ts && \
echo 'import cors from "cors";' >> index.ts && \
echo 'import path from "path";' >> index.ts && \
echo 'import nodeRoutes from "./routes/nodeRoutes";' >> index.ts && \
echo 'import { getNodeStatus } from "./services/nodeService";' >> index.ts && \
echo '' >> index.ts && \
echo 'const app = express();' >> index.ts && \
echo 'const server = http.createServer(app);' >> index.ts && \
echo 'const io = new Server(server, {' >> index.ts && \
echo '  cors: {' >> index.ts && \
echo '    origin: "*",' >> index.ts && \
echo '    methods: ["GET", "POST"]' >> index.ts && \
echo '  }' >> index.ts && \
echo '});' >> index.ts && \
echo '' >> index.ts && \
echo 'app.use(cors());' >> index.ts && \
echo 'app.use(express.json());' >> index.ts && \
echo '' >> index.ts && \
echo 'app.use("/api", nodeRoutes);' >> index.ts && \
echo 'app.use(express.static("/var/www/html"));' >> index.ts && \
echo '' >> index.ts && \
echo 'app.get("*", (req, res) => {' >> index.ts && \
echo '  res.sendFile(path.resolve("/var/www/html/index.html"));' >> index.ts && \
echo '});' >> index.ts && \
echo '' >> index.ts && \
echo 'io.on("connection", (socket) => {' >> index.ts && \
echo '  console.log("Client connected");' >> index.ts && \
echo '  socket.on("disconnect", () => {' >> index.ts && \
echo '    console.log("Client disconnected");' >> index.ts && \
echo '  });' >> index.ts && \
echo '});' >> index.ts

RUN echo '// Emit status updates every 5 seconds' >> index.ts && \
echo 'const emitStatusUpdates = async () => {' >> index.ts && \
echo '  try {' >> index.ts && \
echo '    const status = await getNodeStatus();' >> index.ts && \
echo '    if (status) {' >> index.ts && \
echo '      io.emit("nodeStatus", status);' >> index.ts && \
echo '    }' >> index.ts && \
echo '  } catch (error) {' >> index.ts && \
echo '    console.error("Error emitting status updates:", error);' >> index.ts && \
echo '  }' >> index.ts && \
echo '};' >> index.ts && \
echo '' >> index.ts && \
echo '// Start emitting status updates' >> index.ts && \
echo 'setInterval(emitStatusUpdates, 5000);' >> index.ts && \
echo '' >> index.ts && \
echo 'const PORT = process.env.PORT || 8080;' >> index.ts && \
echo 'server.listen(PORT, () => {' >> index.ts && \
echo '  console.log(`Server running on port ${PORT}`);' >> index.ts && \
echo '});' >> index.ts && \
echo '' >> index.ts && \
echo 'process.on("SIGTERM", () => {' >> index.ts && \
echo '  console.log("SIGTERM signal received: closing HTTP server");' >> index.ts && \
echo '  server.close(() => {' >> index.ts && \
echo '    console.log("HTTP server closed");' >> index.ts && \
echo '    process.exit(0);' >> index.ts && \
echo '  });' >> index.ts && \
echo '});' >> index.ts

# Create a target configuration for TypeScript transpilation
RUN echo '{"compilerOptions": {"target": "ES2016", "module": "CommonJS", "esModuleInterop": true, "moduleResolution": "node", "outDir": "./dist", "strict": false}}' > tsconfig.json

WORKDIR /app/backend

# Copy the built shared module
RUN mkdir -p ./node_modules/shared/
COPY --from=shared-builder /app/shared/dist/ ./node_modules/shared/dist/
COPY --from=shared-builder /app/shared/package.json ./node_modules/shared/

# Build backend
RUN npm run build

# Build stage for Meowcoin binaries
FROM debian:bullseye-slim AS meowcoin-builder
RUN apt-get update && \
apt-get install -y --no-install-recommends \
curl ca-certificates jq wget tar gzip file && \
rm -rf /var/lib/apt/lists/*

# Set Meowcoin version
ARG MEOWCOIN_VERSION="Meow-v2.0.5"

# Download Meowcoin binaries
WORKDIR /tmp
RUN set -ex && \
echo "Downloading Meowcoin version: ${MEOWCOIN_VERSION}" && \
RELEASE_ASSETS=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/tags/${MEOWCOIN_VERSION}) && \
DOWNLOAD_URL=$(echo "${RELEASE_ASSETS}" | jq -r '.assets[] | select(.name | test("x86_64-linux-gnu.tar.gz$")) | .browser_download_url' | head -1) && \
curl -L -o /tmp/meowcoin.tar.gz "${DOWNLOAD_URL}" && \
mkdir -p /tmp/extract && \
tar -xzvf /tmp/meowcoin.tar.gz -C /tmp/extract && \
mkdir -p /usr/local/bin && \
DAEMON_PATH=$(find /tmp/extract -name "meowcoind" -type f | head -1) && \
CLI_PATH=$(find /tmp/extract -name "meowcoin-cli" -type f | head -1) && \
cp -v "$DAEMON_PATH" /usr/local/bin/ && \
cp -v "$CLI_PATH" /usr/local/bin/ && \
chmod 755 /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli

# Final image
FROM debian:bullseye-slim

# Add non-root user first for better security
RUN groupadd -g 10000 meowcoin && \
useradd -u 10000 -g meowcoin -s /bin/bash -m meowcoin && \
mkdir -p /data /config /var/www/html/api

# Install dependencies - reduced list with only necessary ones
RUN apt-get update && \
apt-get install -y --no-install-recommends \
    bash curl jq ca-certificates nodejs npm \
    procps libboost-system1.74.0 libboost-filesystem1.74.0 \
    gosu python3 && \
apt-get clean && \
rm -rf /var/lib/apt/lists/* && \
mkdir -p /run/nginx

# Copy Meowcoin binaries
COPY --from=meowcoin-builder /usr/local/bin/meowcoind /usr/local/bin/
COPY --from=meowcoin-builder /usr/local/bin/meowcoin-cli /usr/local/bin/
RUN chmod 755 /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli

# Copy frontend build
COPY --from=frontend-builder /app/frontend/dist/ /var/www/html/

# Copy backend files
RUN mkdir -p /app/backend/dist/
COPY --from=backend-builder /app/backend/dist/ /app/backend/dist/
COPY --from=backend-builder /app/backend/package.json /app/backend/
WORKDIR /app/backend

# Install production dependencies
RUN npm install --only=production || echo "Backend npm install failed, continuing anyway"

# Add scripts and configs
COPY scripts/functions.sh /scripts/
COPY scripts/auto-configure.sh /scripts/
COPY scripts/entrypoint.sh /scripts/
COPY scripts/healthcheck.sh /scripts/
COPY scripts/backup-manager.sh /scripts/
COPY scripts/update-node.sh /scripts/
RUN chmod +x /scripts/*.sh

# Set proper ownership
RUN chown -R meowcoin:meowcoin /data /config /var/www/html /app

# Set up volumes and ports
VOLUME ["/data", "/config"]
EXPOSE 9766 8788 8080

# Environment variables
ENV HOME=/home/meowcoin \
MEOWCOIN_DATA=/data \
MEOWCOIN_CONFIG=/config \
PATH=/scripts:$PATH \
NODE_ENV=production

# Set up healthcheck
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
CMD ["/scripts/healthcheck.sh"]

# Start both the Meowcoin daemon and web server
ENTRYPOINT ["/scripts/entrypoint.sh"]