// frontend/src/contexts/WebSocketContext.tsx
import { createContext, useContext, useEffect, ReactNode, useState, useRef } from 'react';
import { io, Socket } from 'socket.io-client';

interface WebSocketContextType {
  socket: Socket | null;
  connected: boolean;
  reconnect: () => void;
}

const WebSocketContext = createContext<WebSocketContextType | undefined>(undefined);

interface WebSocketProviderProps {
  children: ReactNode;
}

export const WebSocketProvider = ({ children }: WebSocketProviderProps) => {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [connected, setConnected] = useState(false);
  const socketRef = useRef<Socket | null>(null);
  
  // Function to create and set up socket connection
  const setupSocket = () => {
    // Close existing connection if any
    if (socketRef.current) {
      socketRef.current.disconnect();
    }
    
    // Connect to the WebSocket server
    const socketIo = io(import.meta.env.PROD ? '/' : 'http://localhost:8080', {
      transports: ['websocket'],
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      timeout: 20000,
    });
    
    socketIo.on('connect', () => {
      console.log('WebSocket connected');
      setConnected(true);
    });
    
    socketIo.on('disconnect', (reason) => {
      console.log(`WebSocket disconnected: ${reason}`);
      setConnected(false);
    });
    
    socketIo.on('connect_error', (error) => {
      console.error('Connection error:', error);
      setConnected(false);
    });
    
    // Set socket state and ref
    socketRef.current = socketIo;
    setSocket(socketIo);
    
    return socketIo;
  };
  
  // Function to manually reconnect
  const reconnect = () => {
    console.log('Manually reconnecting WebSocket...');
    setupSocket();
  };
  
  useEffect(() => {
    const socketIo = setupSocket();
    
    // Clean up on unmount
    return () => {
      socketIo.disconnect();
      socketRef.current = null;
    };
  }, []);
  
  return (
    <WebSocketContext.Provider value={{ socket, connected, reconnect }}>
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