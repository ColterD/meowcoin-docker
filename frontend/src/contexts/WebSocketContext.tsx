import { createContext, useContext, useEffect, ReactNode, useState } from 'react';
import { io, Socket } from 'socket.io-client';

interface WebSocketContextType {
  socket: Socket | null;
  connected: boolean;
}

const WebSocketContext = createContext<WebSocketContextType | undefined>(undefined);

interface WebSocketProviderProps {
  children: ReactNode;
}

export const WebSocketProvider = ({ children }: WebSocketProviderProps) => {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [connected, setConnected] = useState(false);
  
  useEffect(() => {
    // Connect to the WebSocket server
    const socketIo = io(import.meta.env.PROD ? '/' : 'http://localhost:8080', {
      transports: ['websocket'],
      reconnection: true,
    });
    
    socketIo.on('connect', () => {
      console.log('WebSocket connected');
      setConnected(true);
    });
    
    socketIo.on('disconnect', () => {
      console.log('WebSocket disconnected');
      setConnected(false);
    });
    
    setSocket(socketIo);
    
    // Clean up on unmount
    return () => {
      socketIo.disconnect();
    };
  }, []);
  
  return (
    <WebSocketContext.Provider value={{ socket, connected }}>
      {children}
    </WebSocketContext.Provider>
  );
};

export const useWebSocket = (): WebSocketContextType => {
  const context = useContext(WebSocketContext);
  if (!context) {
    throw new Error('useWebSocket must be used within a WebSocketProvider');
  }
  return context;
};