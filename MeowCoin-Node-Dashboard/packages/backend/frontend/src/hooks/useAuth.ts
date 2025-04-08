import { useState, useEffect } from 'react';
import api from '../utils/api';

const useAuth = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      api.defaults.headers.common['Authorization'] = Bearer ;
      setIsAuthenticated(true);
    }
  }, []);

  const login = async (credentials: { username: string; password: string }) => {
    try {
      const response = await api.post('/api/login', credentials);
      localStorage.setItem('token', response.data.token);
      api.defaults.headers.common['Authorization'] = Bearer ;
      setIsAuthenticated(true);
      return true;
    } catch (error) {
      return false;
    }
  };

  const logout = () => {
    localStorage.removeItem('token');
    delete api.defaults.headers.common['Authorization'];
    setIsAuthenticated(false);
  };

  return { isAuthenticated, login, logout };
};

export default useAuth;
