import React, { useEffect, useState } from 'react';
import { io } from 'socket.io-client';
import { NodeStatus } from '../../shared/src/types';
import NodeStatus from './NodeStatus';
import SettingsPanel from './SettingsPanel';
import useNodeData from '../hooks/useNodeData';
import LoadingSpinner from './LoadingSpinner';

const Dashboard: React.FC = () => {
  const { nodes, updateNode, loading } = useNodeData();
  const [socket, setSocket] = useState<any>(null);

  useEffect(() => {
    const newSocket = io('http://localhost:3000', { path: '/ws' });
    setSocket(newSocket);

    newSocket.on('connect_error', (err: Error) => {
      console.error('Socket connection error:', err);
    });

    newSocket.on('nodeUpdate', (data: NodeStatus[]) => {
      updateNode(data);
    });

    return () => newSocket.disconnect();
  }, [updateNode]);

  if (loading) return <LoadingSpinner />;

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">MeowCoin Node Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {nodes.map(node => (
          <NodeStatus key={node.id} node={node} onAction={updateNode} />
        ))}
      </div>
      <SettingsPanel />
    </div>
  );
};

export default Dashboard;
