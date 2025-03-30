import { useQuery, useQueryClient } from 'react-query';
import { getDiskUsage } from '../../api/nodeApi';
import { useWebSocketListener } from '../../hooks/useWebSocketListener';
import { DiskUsage as DiskUsageType } from '../../api/nodeApi';
import styles from './DiskUsage.module.css';
import { formatBytes } from '../../utils/formatters';

export default function DiskUsage() {
  const queryClient = useQueryClient();
  
  const { data, isLoading, error } = useQuery('diskUsage', getDiskUsage, {
    refetchInterval: 60000 // Refresh every minute
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
  
  if (error) {
    return (
      <section className="status-card">
        <h2>Disk Usage Details</h2>
        <div>Error loading disk usage: {error instanceof Error ? error.message : 'Unknown error'}</div>
      </section>
    );
  }
  
  if (!data || !data.paths) {
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