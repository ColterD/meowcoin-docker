import { useQuery, useQueryClient } from 'react-query';
import { getNodeStatus } from '../../api/nodeApi';
import { useWebSocketListener } from '../../hooks/useWebSocketListener';
import { NodeStatus } from '../../api/nodeApi';
import styles from './SystemResources.module.css';

export default function SystemResources() {
  const queryClient = useQueryClient();
  
  // Reuse node status query
  const { data, isLoading } = useQuery('nodeStatus', getNodeStatus, {
    refetchInterval: 30000
  });
  
  // Real-time updates
  useWebSocketListener<NodeStatus>('nodeStatus', (newData) => {
    queryClient.setQueryData('nodeStatus', newData);
  });
  
  if (isLoading || !data) {
    return (
      <section className="status-card">
        <h2>System Resources</h2>
        <div>Loading...</div>
      </section>
    );
  }
  
  const { memory, disk } = data.system;
  
  const memoryBarColorClass = 
    parseFloat(memory.percent) > 90 ? styles.dangerBar :
    parseFloat(memory.percent) > 70 ? styles.warningBar :
    styles.normalBar;
  
  const diskBarColorClass = 
    disk.percent > 90 ? styles.dangerBar :
    disk.percent > 70 ? styles.warningBar :
    styles.normalBar;
  
  return (
    <section className="status-card">
      <h2>System Resources</h2>
      <div className="info-grid">
        <div className="info-item">
          <h3>Memory Usage</h3>
          <div className={styles.progressBar}>
            <div 
              className={`${styles.progress} ${memoryBarColorClass}`} 
              style={{ width: `${memory.percent}%` }}
            ></div>
          </div>
          <p>{memory.used}MB / {memory.total}MB ({memory.percent}%)</p>
        </div>
        <div className="info-item">
          <h3>Disk Usage</h3>
          <div className={styles.progressBar}>
            <div 
              className={`${styles.progress} ${diskBarColorClass}`} 
              style={{ width: `${disk.percent}%` }}
            ></div>
          </div>
          <p>{disk.used} / {disk.size} ({disk.percent}%)</p>
        </div>
      </div>
    </section>
  );
}