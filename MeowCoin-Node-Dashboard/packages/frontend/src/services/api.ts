import axios, { AxiosError, AxiosRequestConfig, AxiosResponse } from 'axios';
import { AppError, ErrorCodes } from '@meowcoin/shared';

// Get API URL from environment or use default
const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';

// Create axios instance with default config
export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add token to all requests if available
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  
  return config;
});

// Transform API errors into AppErrors
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (!error.response) {
      return Promise.reject(
        new AppError(ErrorCodes.NETWORK_ERROR, 'Network error occurred', 0)
      );
    }
    
    const { status, data } = error.response as AxiosResponse;
    const message = data?.message || 'Unknown error occurred';
    const code = data?.code || ErrorCodes.UNKNOWN_ERROR;
    
    return Promise.reject(new AppError(code, message, status));
  }
);

// API service with typed methods
export const api = {
  // Generic request method
  request: <T>(config: AxiosRequestConfig) => {
    return apiClient.request<T>(config)
      .then(res => res.data);
  },
  
  // GET request
  get: <T>(url: string, config?: AxiosRequestConfig) => {
    return apiClient.get<T>(url, config)
      .then(res => res.data);
  },
  
  // POST request
  post: <T>(url: string, data?: any, config?: AxiosRequestConfig) => {
    return apiClient.post<T>(url, data, config)
      .then(res => res.data);
  },
  
  // PUT request
  put: <T>(url: string, data?: any, config?: AxiosRequestConfig) => {
    return apiClient.put<T>(url, data, config)
      .then(res => res.data);
  },
  
  // PATCH request
  patch: <T>(url: string, data?: any, config?: AxiosRequestConfig) => {
    return apiClient.patch<T>(url, data, config)
      .then(res => res.data);
  },
  
  // DELETE request
  delete: <T>(url: string, config?: AxiosRequestConfig) => {
    return apiClient.delete<T>(url, config)
      .then(res => res.data);
  },
};