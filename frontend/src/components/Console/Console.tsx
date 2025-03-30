import { useState, useEffect, useRef } from 'react';
import { useQuery, useQueryClient } from 'react-query';
import { getLogs } from '../../api/nodeApi';
import { useWebSocketListener } from '../../hooks/useWebSocketListener';
import { LogResponse } from '../../api/nodeApi';
import styles from './Console.module.css';

export default function Console() {
  const [collapsed, setCollapsed] = useState(() => {
    const savedState = localStorage.getItem('meowcoin-console-collapsed');
    return savedState === 'true';
  });
  
  const consoleOutputRef = useRef<HTMLDivElement>(null);
  const queryClient = useQueryClient();
  
  const [lastTimestamp, setLastTimestamp] = useState(() => {
    const savedTimestamp = localStorage.getItem('meowcoin-logs-timestamp');
    return savedTimestamp ? parseInt(savedTimestamp, 10) : 0;
  });
  
  // Fetch logs
  const { data } = useQuery(['logs', lastTimestamp], () => getLogs(lastTimestamp), {
    refetchInterval: 10000,
    onSuccess: (data) => {
      if (data.success && data.timestamp) {
        setLastTimestamp(data.timestamp);
        localStorage.setItem('meowcoin-logs-timestamp', data.timestamp.toString());
      }
    }
  });
  
  // Real-time updates
  useWebSocketListener<LogResponse>('logs', (newData) => {
    queryClient.setQueryData(['logs', lastTimestamp], newData);
    if (newData.success && newData.timestamp) {
      setLastTimestamp(newData.timestamp);
      localStorage.setItem('meowcoin-logs-timestamp', newData.timestamp.toString());
    }
  });
  
  // Auto-scroll logic
  useEffect(() => {
    if (consoleOutputRef.current && data?.logs?.length) {
      const element = consoleOutputRef.current;
      const isScrolledToBottom = element.scrollHeight - element.clientHeight <= element.scrollTop + 1;
      
      if (isScrolledToBottom) {
        setTimeout(() => {
          if (consoleOutputRef.current) {
            consoleOutputRef.current.scrollTop = consoleOutputRef.current.scrollHeight;
          }
        }, 100);
      }
    }
  }, [data?.logs]);
  
  const toggleCollapse = () => {
    const newState = !collapsed;
    setCollapsed(newState);
    localStorage.setItem('meowcoin-console-collapsed', newState.toString());
  };
  
  return (
    <section className={`status-card ${collapsed ? styles.collapsed : ''}`}>
      <div className={styles.sectionHeader}>
        <h2>Node Console</h2>
        <button onClick={toggleCollapse} className={styles.toggleBtn}>
          <span className={styles.toggleIcon}>{collapsed ? '▶' : '▼'}</span>
        </button>
      </div>
      
      <div className={styles.consoleContainer}>
        <div ref={consoleOutputRef} className={styles.consoleOutput}>
          {data?.logs?.map((log, index) => (
            <div key={index} className={styles.consoleLine}>
              {log}
            </div>
          ))}
          {(!data || !data.logs || data.logs.length === 0) && (
            <div className={styles.consoleLine}>No logs available</div>
          )}
        </div>
      </div>
    </section>
  );
}