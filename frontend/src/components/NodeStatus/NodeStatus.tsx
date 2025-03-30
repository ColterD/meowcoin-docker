import { useQuery, useQueryClient } from 'react-query';
import { getNodeStatus } from '../../api/nodeApi';
import { useWebSocketListener } from '../../hooks/useWebSocketListener';
import { NodeStatus as NodeStatusType } from '../../api/nodeApi';
import VersionAlert from './VersionAlert';
import styles from './NodeStatus.module.css';
import { controlNode } from '../../api/nodeApi';
import { formatBytes, formatBytesPerSecond } from '../../utils/formatters';

export default function NodeStatus() {
  const queryClient = useQueryClient();
  
  // Initial data fetch
  const { data, isLoading } = useQuery('nodeStatus', getNodeStatus, {
    refetchInterval: 30000 // Fallback polling if WebSocket fails
  });
  
  // Real-time updates via WebSocket
  useWebSocketListener<NodeStatusType>('nodeStatus', (newData) => {
    queryClient.setQueryData('nodeStatus', newData);
  });
  
  const handleRestart = async () => {
    if (window.confirm('Are you sure you want to restart the Meowcoin node?')) {
      try {
        const result = await controlNode({ action: 'restart' });
        if (result.success) {
          alert('Node restart initiated. The dashboard will reconnect when the node is back online.');
        } else {
          alert(`Failed to restart node: ${result.message}`);
        }
      } catch (error) {
        console.error('Error restarting node:', error);
        alert('Error restarting node. Check the console for details.');
      }
    }
  };
  
  const handleShutdown = async () => {
    if (window.confirm('Are you sure you want to shutdown the Meowcoin node?')) {
      try {
        const result = await controlNode({ action: 'shutdown' });
        if (result.success) {
          alert('Node shutdown initiated. You will need to restart the container manually.');
        } else {
          alert(`Failed to shutdown node: ${result.message}`);
        }
      } catch (error) {
        console.error('Error shutting down node:', error);
        alert('Error shutting down node. Check the console for details.');
      }
    }
  };
  
  if (isLoading) {
    return (
      <section className="status-card">
        <h2>Node Status</h2>
        <div>Loading...</div>
      </section>
    );
  }
  
  if (!data) {
    return (
      <section className="status-card">
        <h2>Node Status</h2>
        <div>Error loading node status</div>
      </section>
    );
  }
  
  const statusMap = {
    running: { text: 'Running', class: styles.running },
    syncing: { text: 'Syncing', class: styles.syncing },
    stopped: { text: 'Stopped', class: styles.stopped },
    no_connections: { text: 'No Connections', class: styles.error },
    starting: { text: 'Starting', class: '' }
  };
  
  const statusInfo = statusMap[data.status] || { text: 'Unknown', class: '' };
  
  return (
    <section className="status-card">
      <h2>Node Status</h2>
      <div className={styles.statusIndicator}>
        <span className={`${styles.statusLight} ${statusInfo.class}`}></span>
        <span>{statusInfo.text}</span>
      </div>
      
      {data.updateAvailable && (
        <VersionAlert version={data.latestVersion || ''} />
      )}
      
      <div className="info-grid">
        <div className="info-item">
          <h3>Version</h3>
          <p>
            <a 
              href="https://github.com/Meowcoin-Foundation/Meowcoin/tags" 
              target="_blank" 
              rel="noopener noreferrer"
            >
              {data.node.version || 'Unknown'}
            </a>
          </p>
        </div>
        <div className="info-item">
          <h3>Connections</h3>
          <p>{data.node.connections}</p>
        </div>
        <div className="info-item">
          <h3>Blocks</h3>
          <p>{data.blockchain.blocks}</p>
        </div>
        <div className="info-item">
          <h3>Sync Progress</h3>
          <p>{data.blockchain.progress}%</p>
        </div>
      </div>
      
      <div className="info-grid" style={{ marginTop: '20px' }}>
        <div className="info-item">
          <h3>Network Download</h3>
          <p>{formatBytesPerSecond(data.node.bytesReceived)}</p>
        </div>
        <div className="info-item">
          <h3>Network Upload</h3>
          <p>{formatBytesPerSecond(data.node.bytesSent)}</p>
        </div>
        <div className="info-item">
          <h3>Total Downloaded</h3>
          <p>{formatBytes(data.node.bytesReceived)}</p>
        </div>
        <div className="info-item">
          <h3>Total Uploaded</h3>
          <p>{formatBytes(data.node.bytesSent)}</p>
        </div>
      </div>
      
      <div className={styles.controlButtons}>
        <button onClick={handleRestart} className="btn btn-warning">
          Restart Node
        </button>
        <button onClick={handleShutdown} className="btn btn-danger">
          Shutdown Node
        </button>
      </div>
    </section>
  );
}