import { NodeStatus, NodeConfig } from '@meowcoin/shared';
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
