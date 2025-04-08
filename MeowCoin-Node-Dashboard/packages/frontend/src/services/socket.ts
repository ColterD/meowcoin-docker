import { io, Socket } from 'socket.io-client';
import { NodeStatus } from '@meowcoin/shared';

// Get socket URL from environment or use current origin
const SOCKET_URL = process.env.REACT_APP_SOCKET_URL || window.location.origin;
const SOCKET_PATH = '/ws';

export class SocketService {
  private socket: Socket | null = null;
  
  // Connect to WebSocket server
  connect(): Socket {
    if (!this.socket) {
      this.socket = io(SOCKET_URL, { 
        path: SOCKET_PATH,
        autoConnect: true,
        reconnection: true,
        reconnectionAttempts: 5,
        reconnectionDelay: 1000,
      });
      
      this.socket.on('connect_error', (err) => {
        console.error('Socket connection error:', err);
      });
      
      this.socket.on('disconnect', (reason) => {
        console.log(`Socket disconnected due to ${reason}`);
      });
    }
    
    return this.socket;
  }
  
  // Disconnect from WebSocket server
  disconnect(): void {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }
  
  // Check if socket is connected
  isConnected(): boolean {
    return this.socket?.connected || false;
  }
  
  // Listen for node updates
  onNodeUpdate(callback: (data: NodeStatus[]) => void): () => void {
    if (!this.socket) {
      this.connect();
    }
    
    this.socket?.on('nodeUpdate', callback);
    
    // Return unsubscribe function
    return () => {
      this.socket?.off('nodeUpdate', callback);
    };
  }
  
  // Request node status update
  requestNodeStatus(): void {
    if (!this.socket) {
      this.connect();
    }
    
    this.socket?.emit('getNodeStatus');
  }
}

// Export singleton instance
export const socketService = new SocketService();