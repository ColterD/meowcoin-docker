import { useState, useEffect } from 'react';
import { useQuery, useQueryClient } from 'react-query';
import { getNodeStatus, saveSettings } from '../../api/nodeApi';
import { useTheme } from '../../contexts/ThemeContext';
import styles from './Settings.module.css';

interface SettingsProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function Settings({ isOpen, onClose }: SettingsProps) {
  const { theme, setTheme } = useTheme();
  const queryClient = useQueryClient();
  
  const { data } = useQuery('nodeStatus', getNodeStatus);
  
  const [refreshInterval, setRefreshInterval] = useState(30);
  const [maxConnections, setMaxConnections] = useState(50);
  const [enableTxindex, setEnableTxindex] = useState(1);
  
  // Initialize form with current settings
  useEffect(() => {
    if (data?.settings) {
      setMaxConnections(data.settings.maxConnections);
      setEnableTxindex(data.settings.enableTxindex);
    }
    
    // Load refresh interval from localStorage
    const savedInterval = localStorage.getItem('meowcoin-refresh-interval');
    if (savedInterval) {
      setRefreshInterval(parseInt(savedInterval, 10));
    }
  }, [data?.settings]);
  
  const handleSave = async () => {
    try {
      // Save refresh interval to localStorage
      localStorage.setItem('meowcoin-refresh-interval', refreshInterval.toString());
      
      // Save node settings to server
      const result = await saveSettings({
        maxConnections,
        enableTxindex
      });
      
      if (result.success) {
        // Update the cached data
        queryClient.setQueryData('nodeStatus', (oldData: any) => {
          if (!oldData) return oldData;
          return {
            ...oldData,
            settings: {
              ...oldData.settings,
              maxConnections,
              enableTxindex
            }
          };
        });
        
        alert('Settings saved successfully!');
        onClose();
      } else {
        alert(`Failed to save settings: ${result.message}`);
      }
    } catch (error) {
      console.error('Error saving settings:', error);
      alert('Error saving settings. Check the console for details.');
    }
  };
  
  return (
    <div className={`${styles.settingsPanel} ${isOpen ? styles.open : ''}`}>
      <div className={styles.settingsHeader}>
        <h2>Settings</h2>
        <button className={styles.settingsClose} onClick={onClose}>×</button>
      </div>
      
      <div className={styles.settingsGroup}>
        <h3>Display</h3>
        <div className={styles.settingsItem}>
          <label htmlFor="theme-select">Theme</label>
          <select 
            id="theme-select" 
            value={theme} 
            onChange={(e) => setTheme(e.target.value as any)}
          >
            <option value="light">Light</option>
            <option value="dark">Dark</option>
            <option value="auto">Auto (System)</option>
          </select>
        </div>
        <div className={styles.settingsItem}>
          <label htmlFor="refresh-interval">Refresh Interval (seconds)</label>
          <input 
            type="number" 
            id="refresh-interval" 
            min="5" 
            max="300" 
            value={refreshInterval}
            onChange={(e) => {
              let value = parseInt(e.target.value, 10);
              if (value < 5) value = 5;
              if (value > 300) value = 300;
              setRefreshInterval(value);
            }}
          />
        </div>
      </div>
      
      <div className={styles.settingsGroup}>
        <h3>Node Configuration</h3>
        <div className={styles.settingsItem}>
          <label htmlFor="max-connections">Max Connections</label>
          <input 
            type="number" 
            id="max-connections" 
            min="1" 
            max="125"
            value={maxConnections}
            onChange={(e) => {
              let value = parseInt(e.target.value, 10);
              if (value < 1) value = 1;
              if (value > 125) value = 125;
              setMaxConnections(value);
            }}
          />
        </div>
        <div className={styles.settingsItem}>
          <label htmlFor="enable-txindex">Enable Transaction Index</label>
          <select 
            id="enable-txindex"
            value={enableTxindex}
            onChange={(e) => setEnableTxindex(parseInt(e.target.value, 10))}
          >
            <option value={1}>Yes</option>
            <option value={0}>No</option>
          </select>
        </div>
      </div>
      
      <div className={styles.settingsGroup}>
        <button onClick={handleSave} className="btn btn-primary">
          Save Settings
        </button>
      </div>
    </div>
  );
}