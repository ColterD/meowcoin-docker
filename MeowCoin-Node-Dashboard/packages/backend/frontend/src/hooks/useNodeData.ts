import { useState, useEffect, useCallback } from 'react';
import { NodeStatus, NodeConfig } from '../../shared/src/types';
import { io } from 'socket.io-client';
import api from '../utils/api';

const useNodeData = () => {
  const [nodes, setNodes] = useState<NodeStatus[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchNodes = async () => {
    try {
      const response = await api.get('/api/node/status');
      setNodes(response.data.data);
    } catch (error) {
      console.error('Failed to fetch nodes:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateNode = useCallback((updatedNodes: NodeStatus[] | ((prev: NodeStatus[]) => NodeStatus[])) => {
    setNodes(prev =>
      typeof updatedNodes === 'function' ? updatedNodes(prev) : updatedNodes
    );
  }, []);

  const updateConfig = async (newConfig: Partial<NodeConfig>) => {
    try {
      await api.patch('/api/config', newConfig);
      fetchNodes();
    } catch (error) {
      console.error('Failed to update config:', error);
    }
  };

  useEffect(() => {
    fetchNodes();

    const socket = io('http://localhost:3000', { path: '/ws' });
    socket.on('nodeUpdate', (data: NodeStatus[]) => {
      updateNode(data);
    });

    return () => socket.disconnect();
  }, [updateNode]);

  return { nodes, updateNode, updateConfig, loading };
};

export default useNodeData;
