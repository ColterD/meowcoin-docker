import React, { useState } from 'react';
import useNodeData from '../hooks/useNodeData';

const SettingsPanel: React.FC = () => {
  const { updateConfig } = useNodeData();
  const [port, setPort] = useState<number>(3000);
  const [syncInterval, setSyncInterval] = useState<number>(5000);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    updateConfig({ port, syncInterval });
  };

  return (
    <div className="mt-8 bg-white dark:bg-gray-800 p-4 rounded shadow">
      <h2 className="text-xl font-semibold mb-4">Settings</h2>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="port">Port</label>
          <input
            type="number"
            id="port"
            value={port}
            onChange={(e) => setPort(Number(e.target.value))}
            className="w-full p-2 border rounded dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label htmlFor="syncInterval">Sync Interval (ms)</label>
          <input
            type="number"
            id="syncInterval"
            value={syncInterval}
            onChange={(e) => setSyncInterval(Number(e.target.value))}
            className="w-full p-2 border rounded dark:bg-gray-700 dark:text-white"
          />
        </div>
        <button type="submit" className="bg-blue-500 text-white p-2 rounded">
          Save Settings
        </button>
      </form>
    </div>
  );
};

export default SettingsPanel;
