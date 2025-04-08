import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { NodeStatus, NodeConfig, NODE_ACTIONS, AppError, ErrorCodes, ApiResponse } from '@meowcoin/shared';
import { api } from '../services/api';
import { socketService } from '../services/socket';

// Context state type
interface NodeContextState {
  nodes: NodeStatus[];
  loading: boolean;
  error: AppError | null;
  refreshNodes: () => Promise<void>;
  updateNodeStatus: (id: string, action: string) => Promise<void>;
  updateConfig: (config: Partial<NodeConfig>) => Promise<void>;
}

// Create context with default values
const NodeContext = createContext<NodeContextState | undefined>(undefined);

// Provider component
export const NodeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [nodes, setNodes] = useState<NodeStatus[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<AppError | null>(null);

  // Fetch all nodes
  const refreshNodes = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await api.get<ApiResponse<NodeStatus[]>>('/node/status');
      setNodes(response.data);
    } catch (err) {
      console.error('Failed to fetch nodes:', err);
      setError(err as AppError);
    } finally {
      setLoading(false);
    }
  }, []);

  // Update node status
  const updateNodeStatus = useCallback(async (id: string, action: string) => {
    try {
      setError(null);
      
      // Validate action
      if (!Object.values(NODE_ACTIONS).includes(action as any)) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          `Invalid action: ${action}. Must be one of: ${Object.values(NODE_ACTIONS).join(', ')}`,
          400
        );
      }
      
      await api.post<ApiResponse<NodeStatus>>('/node/action', { id, action });
      
      // No need to update state here, WebSocket will handle it
    } catch (err) {
      console.error(`Failed to ${action} node:`, err);
      setError(err as AppError);
      throw err;
    }
  }, []);

  // Update configuration
  const updateConfig = useCallback(async (config: Partial<NodeConfig>) => {
    try {
      setError(null);
      await api.patch<ApiResponse<NodeConfig>>('/config', config);
    } catch (err) {
      console.error('Failed to update config:', err);
      setError(err as AppError);
      throw err;
    }
  }, []);

  // Subscribe to WebSocket updates
  useEffect(() => {
    // Initial data fetch
    refreshNodes();
    
    // Connect and listen for updates
    const unsubscribe = socketService.onNodeUpdate((data) => {
      setNodes(data);
      setLoading(false);
    });
    
    // Request initial status
    socketService.requestNodeStatus();
    
    // Cleanup on unmount
    return () => {
      unsubscribe();
    };
  }, [refreshNodes]);

  return (
    <NodeContext.Provider
      value={{
        nodes,
        loading,
        error,
        refreshNodes,
        updateNodeStatus,
        updateConfig,
      }}
    >
      {children}
    </NodeContext.Provider>
  );
};

// Custom hook to use the context
export const useNodeContext = () => {
  const context = useContext(NodeContext);
  
  if (context === undefined) {
    throw new Error('useNodeContext must be used within a NodeProvider');
  }
  
  return context;
};