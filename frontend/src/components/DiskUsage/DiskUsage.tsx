import { useQuery, useQueryClient } from 'react-query';
import { getDiskUsage } from '../../api/nodeApi';
import { useWebSocketListener } from '../../hooks/useWebSocketListener';
import { DiskUsage as DiskUsageType } from '../../api/nodeApi';
import styles from './DiskUsage.module.css';

export default function DiskUsage() {
  const queryClient = useQueryClient();
  
  const { data, isLoading } = useQuery('diskUsage', getDiskUsage, {
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

function formatBytes(bytes: number, decimals = 2) {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
}