import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { AppError, ErrorCodes, ApiResponse, UserData } from '@meowcoin/shared';
import { api } from '../services/api';

// Login credentials type
interface LoginCredentials {
  username: string;
  password: string;
}

// Auth state type
interface AuthState {
  user: UserData | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: AppError | null;
}

// Context interface
interface AuthContextState extends AuthState {
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => void;
}

// Auth response type
interface AuthResponse {
  token: string;
  user: UserData;
}

// Create context
const AuthContext = createContext<AuthContextState | undefined>(undefined);

// Provider component
export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, setState] = useState<AuthState>({
    user: null,
    token: localStorage.getItem('token'),
    isAuthenticated: !!localStorage.getItem('token'),
    isLoading: true,
    error: null,
  });

  // Check token validity on load
  useEffect(() => {
    const initAuth = async () => {
      const token = localStorage.getItem('token');
      
      if (token) {
        try {
          // This would typically validate the token with the server
          // For now, we'll just set authenticated state based on token presence
          const userJson = localStorage.getItem('user');
          const user = userJson ? JSON.parse(userJson) : null;
          
          setState(prev => ({
            ...prev,
            isAuthenticated: true,
            user,
            isLoading: false,
          }));
        } catch (error) {
          // Token invalid, clear storage
          localStorage.removeItem('token');
          localStorage.removeItem('user');
          
          setState(prev => ({
            ...prev,
            isAuthenticated: false,
            user: null,
            token: null,
            isLoading: false,
          }));
        }
      } else {
        setState(prev => ({
          ...prev,
          isLoading: false,
        }));
      }
    };

    initAuth();
  }, []);

  // Login function
  const login = useCallback(async (credentials: LoginCredentials) => {
    try {
      setState(prev => ({ ...prev, isLoading: true, error: null }));
      
      const response = await api.post<ApiResponse<AuthResponse>>('/auth/login', credentials);
      const { token, user } = response.data;
      
      // Store in localStorage
      localStorage.setItem('token', token);
      localStorage.setItem('user', JSON.stringify(user));
      
      setState({
        user,
        token,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      });
    } catch (error) {
      setState(prev => ({ 
        ...prev, 
        isLoading: false, 
        error: error as AppError,
        isAuthenticated: false,
      }));
      throw error;
    }
  }, []);

  // Logout function
  const logout = useCallback(() => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    
    setState({
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,
    });
  }, []);

  return (
    <AuthContext.Provider
      value={{
        ...state,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

// Custom hook for using auth context
export const useAuth = () => {
  const context = useContext(AuthContext);
  
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  
  return context;
};