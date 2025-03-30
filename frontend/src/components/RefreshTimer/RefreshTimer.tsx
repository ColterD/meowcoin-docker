import { useState, useEffect } from 'react';
import { useInterval } from '../../hooks/useInterval';
import styles from './RefreshTimer.module.css';

export default function RefreshTimer() {
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
  useEffect(() => {
    const handleStorageChange = () => {
      const savedInterval = localStorage.getItem('meowcoin-refresh-interval');
      if (savedInterval) {
        const newInterval = parseInt(savedInterval, 10);
        if (newInterval !== refreshInterval) {
          setRefreshInterval(newInterval);
        }
      }
    };
    
    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, [refreshInterval]);
  
  // Countdown timer
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
}