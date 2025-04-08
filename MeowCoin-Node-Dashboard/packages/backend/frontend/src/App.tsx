import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import { ThemeProvider } from './styles/theme';
import Dashboard from './components/Dashboard';
import Home from './pages/Home';
import NotFound from './pages/NotFound';
import useTheme from './hooks/useTheme';
import ErrorBoundary from './components/ErrorBoundary';

function App() {
  const { theme } = useTheme();

  return (
    <ThemeProvider theme={theme}>
      <ErrorBoundary>
        <Router>
          <div className="min-h-screen bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100 transition-colors duration-300">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="*" element={<NotFound />} />
            </Routes>
          </div>
        </Router>
      </ErrorBoundary>
    </ThemeProvider>
  );
}

export default App;
