// frontend/src/components/RefreshTimer/RefreshTimer.tsx
import { useState, useEffect, useCallback, memo } from 'react';
import { useInterval } from '../../hooks/useInterval';
import styles from './RefreshTimer.module.css';

const RefreshTimer = memo(() => {
  const [refreshInterval, setRefreshInterval] = useState(() => {
    const savedInterval = localStorage.getItem('meowcoin-refresh-interval');
    return savedInterval ? parseInt(savedInterval, 10) : 30;
  });
  
  const [countDown, setCountDown] = useState(refreshInterval);
  
  // Reset countdown when interval changes
  useEffect(() => {
    setCountDown(refreshInterval);
  }, [refreshInterval]);
  
  // Check for changes to refreshInterval in localStorage
  const handleStorageChange = useCallback((event: StorageEvent) => {
    if (event.key === 'meowcoin-refresh-interval' && event.newValue) {
      const newInterval = parseInt(event.newValue, 10);
      if (!isNaN(newInterval) && newInterval !== refreshInterval) {
        setRefreshInterval(newInterval);
      }
    }
  }, [refreshInterval]);
  
  useEffect(() => {
    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, [handleStorageChange]);
  
  // Countdown timer with controlled render
  useInterval(() => {
    setCountDown((prev) => {
      if (prev <= 1) {
        return refreshInterval;
      }
      return prev - 1;
    });
  }, 1000);
  
  const percentage = (countDown / refreshInterval) * 100;
  
  return (
    <div className={styles.refreshTimer}>
      <div className={styles.progressBar}>
        <div 
          className={styles.progress} 
          style={{ width: `${percentage}%` }}
        ></div>
      </div>
      <span className={styles.refreshTimerText}>{countDown}s</span>
    </div>
  );
});

RefreshTimer.displayName = 'RefreshTimer';

export default RefreshTimer;