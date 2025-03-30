import { useState } from 'react';
import { QueryClient, QueryClientProvider } from 'react-query';
import { ThemeProvider } from './contexts/ThemeContext';
import { WebSocketProvider } from './contexts/WebSocketContext';
import NodeStatus from './components/NodeStatus/NodeStatus';
import SystemResources from './components/SystemResources/SystemResources';
import DiskUsage from './components/DiskUsage/DiskUsage';
import Console from './components/Console/Console';
import Settings from './components/Settings/Settings';
import RefreshTimer from './components/RefreshTimer/RefreshTimer';
import './App.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      staleTime: 30000,
    },
  },
});

function App() {
  const [showSettings, setShowSettings] = useState(false);
  
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <WebSocketProvider>
          <div className="container">
            <header>
              <div className="logo">🐱</div>
              <h1>Meowcoin Node Dashboard</h1>
            </header>
            
            <main>
              <NodeStatus />
              <SystemResources />
              <DiskUsage />
              <Console />
            </main>
            
            <footer>
              <div className="footer-content">
                <p>Last updated: <span id="last-updated">{new Date().toLocaleString()}</span></p>
                <RefreshTimer />
              </div>
            </footer>
            
            <button 
              className="settings-toggle" 
              onClick={() => setShowSettings(true)}
            >
              ⚙️
            </button>
            
            <Settings 
              isOpen={showSettings} 
              onClose={() => setShowSettings(false)} 
            />
          </div>
        </WebSocketProvider>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;