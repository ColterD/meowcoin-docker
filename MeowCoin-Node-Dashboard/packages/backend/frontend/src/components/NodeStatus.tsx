import React from 'react';
import { NodeStatus } from '../../shared/src/types';
import { formatPercentage } from '../utils/formatters';

interface NodeStatusProps {
  node: NodeStatus;
  onAction: (id: string, action: 'start' | 'stop' | 'restart') => void;
}

const NodeStatus: React.FC<NodeStatusProps> = ({ node, onAction }) => {
  return (
    <div className="bg-white dark:bg-gray-800 p-4 rounded shadow">
      <h2 className="text-xl font-semibold">{node.name}</h2>
      <p>Status: {node.status}</p>
      <p>CPU: {formatPercentage(node.cpuUsage)}</p>
      <p>Memory: {formatPercentage(node.memoryUsage)}</p>
      <p>Disk: {formatPercentage(node.diskUsage)}</p>
      <p>Last Updated: {node.lastUpdated.toLocaleTimeString()}</p>
      <div className="mt-4 space-x-2">
        <button
          onClick={() => onAction(node.id, 'start')}
          className="bg-green-500 text-white p-2 rounded"
          disabled={node.status === 'running'}
        >
          Start
        </button>
        <button
          onClick={() => onAction(node.id, 'stop')}
          className="bg-red-500 text-white p-2 rounded"
          disabled={node.status === 'stopped'}
        >
          Stop
        </button>
        <button
          onClick={() => onAction(node.id, 'restart')}
          className="bg-yellow-500 text-white p-2 rounded"
        >
          Restart
        </button>
      </div>
    </div>
  );
};

export default NodeStatus;
