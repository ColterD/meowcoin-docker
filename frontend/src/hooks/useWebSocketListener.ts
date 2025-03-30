import { useEffect } from 'react';
import { useWebSocket } from '../contexts/WebSocketContext';

export function useWebSocketListener<T>(
  event: string, 
  callback: (data: T) => void
) {
  const { socket } = useWebSocket();
  
  useEffect(() => {
    if (!socket) return;
    
    socket.on(event, callback);
    
    return () => {
      socket.off(event, callback);
    };
  }, [socket, event, callback]);
}