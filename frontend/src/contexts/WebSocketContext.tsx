// frontend/src/contexts/WebSocketContext.tsx
import { createContext, useContext, useEffect, ReactNode, useState, useRef, useCallback } from 'react';
import { io, Socket } from 'socket.io-client';

interface WebSocketContextType {
  socket: Socket | null;
  connected: boolean;
  reconnect: () => void;
  connectionError: string | null;
  connectionStatus: 'connected' | 'connecting' | 'disconnected' | 'error';
}

const WebSocketContext = createContext<WebSocketContextType | undefined>(undefined);

interface WebSocketProviderProps {
  children: ReactNode;
}

export const WebSocketProvider = ({ children }: WebSocketProviderProps) => {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [connected, setConnected] = useState(false);
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [connectionStatus, setConnectionStatus] = useState<'connected' | 'connecting' | 'disconnected' | 'error'>('disconnected');
  const socketRef = useRef<Socket | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const reconnectTimerRef = useRef<number | null>(null);
  const maxReconnectAttempts = 10;
  
  // Function to calculate exponential backoff delay
  const getBackoffDelay = useCallback((attempt: number) => {
    // Start with 1000ms, double each time, cap at 30 seconds
    return Math.min(1000 * Math.pow(2, attempt), 30000);
  }, []);
  
  // Function to clear any existing timers
  const clearReconnectTimer = useCallback(() => {
    if (reconnectTimerRef.current !== null) {
      window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
  }, []);
  
  // Function to create and set up socket connection
  const setupSocket = useCallback(() => {
    // Clear existing timers
    clearReconnectTimer();
    
    // Clear any previous error message
    setConnectionError(null);
    setConnectionStatus('connecting');
    
    // Close existing connection if any
    if (socketRef.current) {
      socketRef.current.disconnect();
      socketRef.current = null;
    }
    
    try {
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
        setConnectionStatus('connected');
        reconnectAttemptsRef.current = 0;
        setConnectionError(null);
      });
      
      socketIo.on('disconnect', (reason) => {
        console.log(`WebSocket disconnected: ${reason}`);
        setConnected(false);
        setConnectionStatus('disconnected');
        
        // If server disconnect, attempt to reconnect automatically with exponential backoff
        if (reason === 'io server disconnect') {
          clearReconnectTimer();
          
          reconnectTimerRef.current = window.setTimeout(() => {
            if (reconnectAttemptsRef.current < maxReconnectAttempts) {
              const delay = getBackoffDelay(reconnectAttemptsRef.current);
              console.log(`Attempting reconnect in ${delay}ms (attempt ${reconnectAttemptsRef.current + 1}/${maxReconnectAttempts})`);
              reconnectAttemptsRef.current++;
              socketIo.connect();
            } else {
              setConnectionError(`Failed to reconnect after ${maxReconnectAttempts} attempts. Please try manually reconnecting.`);
              setConnectionStatus('error');
            }
          }, getBackoffDelay(reconnectAttemptsRef.current));
        }
      });
      
      socketIo.on('connect_error', (error) => {
        console.error('Connection error:', error);
        setConnected(false);
        setConnectionStatus('error');
        setConnectionError(`Connection error: ${error.message}`);
      });
      
      // Set socket state and ref
      socketRef.current = socketIo;
      setSocket(socketIo);
      
      return socketIo;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      setConnectionError(`Failed to setup socket: ${errorMessage}`);
      setConnectionStatus('error');
      console.error('Error setting up socket:', error);
      return null;
    }
  }, [getBackoffDelay, clearReconnectTimer]);
  
  // Function to manually reconnect
  const reconnect = useCallback(() => {
    console.log('Manually reconnecting WebSocket...');
    reconnectAttemptsRef.current = 0;
    setConnectionError(null);
    setupSocket();
  }, [setupSocket]);
  
  // Listen for global refresh events
  useEffect(() => {
    const handleRefresh = () => {
      if (socketRef.current && connected) {
        socketRef.current.emit('refresh');
      }
    };
    
    window.addEventListener('refresh-data', handleRefresh);
    
    return () => {
      window.removeEventListener('refresh-data', handleRefresh);
    };
  }, [connected]);
  
  useEffect(() => {
    const socketIo = setupSocket();
    
    // Add ping to keep connection alive
    const pingInterval = window.setInterval(() => {
      if (socketRef.current && connected) {
        socketRef.current.emit('ping');
      }
    }, 30000);
    
    // Clean up on unmount
    return () => {
      window.clearInterval(pingInterval);
      clearReconnectTimer();
      if (socketIo) {
        socketIo.disconnect();
      }
      socketRef.current = null;
    };
  }, [setupSocket, connected, clearReconnectTimer]);
  
  return (
    <WebSocketContext.Provider value={{ socket, connected, reconnect, connectionError, connectionStatus }}>
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