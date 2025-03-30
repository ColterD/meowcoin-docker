import { useQuery, useQueryClient } from 'react-query';
import { getDiskUsage } from '../../api/nodeApi';
import { useWebSocketListener } from '../../hooks/useWebSocketListener';
import { DiskUsage as DiskUsageType } from '../../api/nodeApi';
import styles from './DiskUsage.module.css';
import { formatBytes } from '../../utils/formatters';
import { useWebSocket } from '../../contexts/WebSocketContext';

export default function DiskUsage() {
  const queryClient = useQueryClient();
  const { connected, connectionError, reconnect } = useWebSocket();
  
  const { data, isLoading, error, refetch } = useQuery('diskUsage', getDiskUsage, {
    refetchInterval: connected ? false : 60000, // Only poll if WebSocket is disconnected
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * Math.pow(2, attemptIndex), 30000)
  });
  
  // Real-time updates
  useWebSocketListener<DiskUsageType>('diskUsage', (newData) => {
    queryClient.setQueryData('diskUsage', newData);
  });
  
  if (isLoading) {
    return (
      <section className="status-card">
        <h2>Disk Usage Details</h2>
        <div>Loading detailed disk usage...</div>
      </section>
    );
  }
  
  // Handle WebSocket connection errors
  if (connectionError && !data) {
    return (
      <section className="status-card">
        <h2>Disk Usage Details</h2>
        <div className="error-message">
          <p>Error connecting to server: {connectionError}</p>
          <button className="btn btn-primary" onClick={reconnect}>
            Reconnect
          </button>
        </div>
      </section>
    );
  }
  
  if (error) {
    return (
      <section className="status-card">
        <h2>Disk Usage Details</h2>
        <div className="error-message">
          <p>Error loading disk usage: {error instanceof Error ? error.message : 'Unknown error'}</p>
          <button className="btn btn-primary" onClick={() => refetch()}>
            Try Again
          </button>
        </div>
      </section>
    );
  }
  
  if (!data || !data.paths || data.paths.length === 0) {
    return (
      <section className="status-card">
        <h2>Disk Usage Details</h2>
        <div>No disk usage details available.</div>
      </section>
    );
  }
  
  // Sort paths by size (largest first)
  const sortedPaths = [...data.paths].sort((a, b) => b.sizeBytes - a.sizeBytes);
  
  return (
    <section className="status-card">
      <h2>Disk Usage Details</h2>
      <div className={styles.diskUsageList}>
        {sortedPaths.map((item, index) => (
          <div key={index} className={styles.diskUsageItem}>
            <div className={styles.diskUsagePath}>{item.path}</div>
            <div className={styles.diskUsageSize}>
              {formatBytes(item.sizeBytes)}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}