// frontend/src/contexts/WebSocketContext.tsx
import { createContext, useContext, useEffect, ReactNode, useState, useRef, useCallback } from 'react';
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
  const reconnectAttemptsRef = useRef(0);
  const maxReconnectAttempts = 10;
  
  // Function to create and set up socket connection
  const setupSocket = useCallback(() => {
    // Close existing connection if any
    if (socketRef.current) {
      socketRef.current.disconnect();
      socketRef.current = null;
    }
    
    // Determine server URL based on environment
    const baseUrl = typeof window !== 'undefined' && window.location.origin ? 
      window.location.origin : 
      (import.meta.env.DEV ? 'http://localhost:8080' : '/');
    
    // Connect to the WebSocket server
    const socketIo = io(baseUrl, {
      transports: ['websocket'],
      reconnection: true,
      reconnectionAttempts: maxReconnectAttempts,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      timeout: 20000,
    });
    
    socketIo.on('connect', () => {
      console.log('WebSocket connected');
      setConnected(true);
      reconnectAttemptsRef.current = 0;
    });
    
    socketIo.on('disconnect', (reason) => {
      console.log(`WebSocket disconnected: ${reason}`);
      setConnected(false);
      
      // If server disconnect, attempt to reconnect automatically
      if (reason === 'io server disconnect') {
        setTimeout(() => {
          if (reconnectAttemptsRef.current < maxReconnectAttempts) {
            reconnectAttemptsRef.current++;
            socketIo.connect();
          }
        }, 1000);
      }
    });
    
    socketIo.on('connect_error', (error) => {
      console.error('Connection error:', error);
      setConnected(false);
    });
    
    // Set socket state and ref
    socketRef.current = socketIo;
    setSocket(socketIo);
    
    return socketIo;
  }, []);
  
  // Function to manually reconnect
  const reconnect = useCallback(() => {
    console.log('Manually reconnecting WebSocket...');
    reconnectAttemptsRef.current = 0;
    setupSocket();
  }, [setupSocket]);
  
  useEffect(() => {
    const socketIo = setupSocket();
    
    // Add ping to keep connection alive
    const pingInterval = setInterval(() => {
      if (socketRef.current && connected) {
        socketRef.current.emit('ping');
      }
    }, 30000);
    
    // Clean up on unmount
    return () => {
      clearInterval(pingInterval);
      socketIo.disconnect();
      socketRef.current = null;
    };
  }, [setupSocket]);
  
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