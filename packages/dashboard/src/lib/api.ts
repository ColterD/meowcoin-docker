import axios from 'axios';
import { AppError, ErrorCode } from '@meowcoin/shared';

// Create axios instance
export const api = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add request interceptor
api.interceptors.request.use(
  (config) => {
    // Get token from localStorage
    const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null;
    
    // If token exists, add to headers
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    
    return config;
  },
  (error) => Promise.reject(error)
);

// Add response interceptor
api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Handle API errors
    if (error.response) {
      const { status, data } = error.response;
      
      // Create AppError from response
      const appError = new AppError(
        data.code || ErrorCode.INTERNAL_SERVER_ERROR,
        data.message || 'An unexpected error occurred',
        status,
        data.details
      );
      
      return Promise.reject(appError);
    }
    
    // Handle network errors
    if (error.request) {
      const appError = new AppError(
        ErrorCode.SERVICE_UNAVAILABLE,
        'Network error. Please check your connection.',
        503
      );
      
      return Promise.reject(appError);
    }
    
    // Handle other errors
    return Promise.reject(error);
  }
);