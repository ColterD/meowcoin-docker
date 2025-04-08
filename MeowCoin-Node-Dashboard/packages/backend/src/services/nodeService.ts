import { NodeStatus, NodeConfig, NODE_STATUS, NODE_ACTIONS, AppError, ErrorCodes } from '@meowcoin/shared';
import configService from '../config';
import socketService from './socketService';

export class NodeService {
  private nodes: NodeStatus[] = [];
  private monitorInterval: NodeJS.Timeout | null = null;

  constructor() {
    this.initializeNodes();
  }

  private initializeNodes(): void {
    // In a real application, this would likely come from a database
    this.nodes = [
      { 
        id: 'node1', 
        name: 'MeowNode-1', 
        status: NODE_STATUS.RUNNING, 
        cpuUsage: 30, 
        memoryUsage: 45, 
        diskUsage: 60, 
        lastUpdated: new Date().toISOString() 
      },
      { 
        id: 'node2', 
        name: 'MeowNode-2', 
        status: NODE_STATUS.STOPPED, 
        cpuUsage: 0, 
        memoryUsage: 0, 
        diskUsage: 20, 
        lastUpdated: new Date().toISOString() 
      },
    ];
  }

  public getNodes(): NodeStatus[] {
    return this.nodes.map(node => ({
      ...node,
      lastUpdated: new Date().toISOString(),
    }));
  }

  public getNodeById(id: string): NodeStatus {
    const node = this.nodes.find(n => n.id === id);
    if (!node) {
      throw new AppError(ErrorCodes.NOT_FOUND, `Node with id ${id} not found`, 404);
    }
    return {
      ...node,
      lastUpdated: new Date().toISOString(),
    };
  }

  public updateNodeStatus(id: string, action: typeof NODE_ACTIONS[keyof typeof NODE_ACTIONS]): NodeStatus {
    const nodeIndex = this.nodes.findIndex(n => n.id === id);
    if (nodeIndex === -1) {
      throw new AppError(ErrorCodes.NOT_FOUND, `Node with id ${id} not found`, 404);
    }

    const node = this.nodes[nodeIndex];

    switch (action) {
      case NODE_ACTIONS.START:
        node.status = NODE_STATUS.RUNNING;
        break;
      case NODE_ACTIONS.STOP:
        node.status = NODE_STATUS.STOPPED;
        node.cpuUsage = 0;
        node.memoryUsage = 0;
        break;
      case NODE_ACTIONS.RESTART:
        node.status = NODE_STATUS.RUNNING;
        break;
      default:
        throw new AppError(ErrorCodes.VALIDATION_ERROR, `Invalid action: ${action}`, 400);
    }

    node.lastUpdated = new Date().toISOString();
    this.nodes[nodeIndex] = node;

    // Broadcast update to all connected clients
    socketService.broadcastToAll('nodeUpdate', this.getNodes());
    
    return node;
  }

  public startMonitoring(): void {
    if (this.monitorInterval) {
      clearInterval(this.monitorInterval);
    }

    this.monitorInterval = setInterval(() => {
      let updated = false;

      this.nodes.forEach(node => {
        if (node.status === NODE_STATUS.RUNNING) {
          node.cpuUsage = Math.min(100, node.cpuUsage + Math.random() * 5 - 2.5);
          node.memoryUsage = Math.min(100, node.memoryUsage + Math.random() * 3 - 1.5);
          node.diskUsage = Math.min(100, node.diskUsage + Math.random() * 0.5);
          node.lastUpdated = new Date().toISOString();
          updated = true;
        }
      });

      if (updated) {
        socketService.broadcastToAll('nodeUpdate', this.getNodes());
      }
    }, configService.syncInterval);
  }

  public stopMonitoring(): void {
    if (this.monitorInterval) {
      clearInterval(this.monitorInterval);
      this.monitorInterval = null;
    }
  }
}

export default new NodeService();