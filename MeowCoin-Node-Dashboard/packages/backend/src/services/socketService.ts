import { Server } from 'socket.io';
import { Server as HttpServer } from 'http';
import { NodeStatus } from '@meowcoin/shared';

export class SocketService {
  private io: Server | null = null;

  initialize(httpServer: HttpServer): Server {
    this.io = new Server(httpServer, {
      cors: { origin: '*' },
      path: '/ws',
    });

    this.io.on('connection', (socket) => {
      console.log('New WebSocket connection');
      
      socket.on('getNodeStatus', () => {
        this.emitNodeUpdate(socket.id);
      });

      socket.on('disconnect', () => {
        console.log('WebSocket disconnected');
      });
    });

    return this.io;
  }

  emitNodeUpdate(socketId?: string, data?: NodeStatus[]): void {
    if (!this.io) return;

    if (socketId && data) {
      this.io.to(socketId).emit('nodeUpdate', data);
    } else if (data) {
      this.io.emit('nodeUpdate', data);
    }
  }

  broadcastToAll(event: string, data: any): void {
    if (!this.io) return;
    this.io.emit(event, data);
  }
}

export default new SocketService();