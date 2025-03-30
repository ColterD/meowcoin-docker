import { createContext, useState, useEffect, useContext, ReactNode } from 'react';

type Theme = 'light' | 'dark' | 'auto';

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  currentTheme: 'light' | 'dark';
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

interface ThemeProviderProps {
  children: ReactNode;
}

export const ThemeProvider = ({ children }: ThemeProviderProps) => {
  const [theme, setTheme] = useState<Theme>(() => {
    const savedTheme = localStorage.getItem('meowcoin-theme');
    return (savedTheme as Theme) || 'auto';
  });
  
  const [currentTheme, setCurrentTheme] = useState<'light' | 'dark'>('light');
  
  useEffect(() => {
    const applyTheme = () => {
      let effectiveTheme: 'light' | 'dark' = 'light';
      
      if (theme === 'auto') {
        effectiveTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      } else {
        effectiveTheme = theme as 'light' | 'dark';
      }
      
      document.documentElement.setAttribute('data-theme', effectiveTheme);
      setCurrentTheme(effectiveTheme);
    };
    
    applyTheme();
    
    // Save to localStorage
    localStorage.setItem('meowcoin-theme', theme);
    
    // Listen for system preference changes
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = () => {
      if (theme === 'auto') {
        applyTheme();
      }
    };
    
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, [theme]);
  
  const updateTheme = (newTheme: Theme) => {
    setTheme(newTheme);
  };
  
  return (
    <ThemeContext.Provider value={{ theme, setTheme: updateTheme, currentTheme }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = (): ThemeContextType => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};