import { useCallback } from 'react';
import { updateNode } from '../../api/nodeApi';
import styles from './VersionAlert.module.css';

interface VersionAlertProps {
  version: string;
}

export default function VersionAlert({ version }: VersionAlertProps) {
  const handleUpdate = useCallback(async () => {
    if (window.confirm(`Are you sure you want to update to ${version}?`)) {
      try {
        const result = await updateNode({ version });
        if (result.success) {
          alert('Update initiated. The node will restart when the update is complete.');
        } else {
          alert(`Failed to update: ${result.message}`);
        }
      } catch (error) {
        console.error('Error updating node:', error);
        alert('Error updating node. Check the console for details.');
      }
    }
  }, [version]);
  
  return (
    <div className={styles.alertContainer}>
      <p>New version available!</p>
      <button className="btn btn-primary" onClick={handleUpdate}>
        Update to {version}
      </button>
    </div>
  );
}