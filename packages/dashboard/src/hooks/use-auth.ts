import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { UserProfile } from '@meowcoin/shared';
import { api } from '@/lib/api';

interface AuthState {
  token: string | null;
  user: UserProfile | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
}

export const useAuth = create<AuthState>()(
  persist(
    (set, get) => ({
      token: null,
      user: null,
      isLoading: false,
      isAuthenticated: false,

      login: async (username: string, password: string) => {
        set({ isLoading: true });
        try {
          const response = await api.post('/auth/login', { username, password });
          const { token, user } = response.data.data;
          
          // Set token in API client
          api.defaults.headers.common.Authorization = `Bearer ${token}`;
          
          set({
            token,
            user,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error) {
          set({ isLoading: false });
          throw error;
        }
      },

      logout: () => {
        // Remove token from API client
        delete api.defaults.headers.common.Authorization;
        
        set({
          token: null,
          user: null,
          isAuthenticated: false,
        });
      },

      refreshUser: async () => {
        const { token } = get();
        if (!token) return;

        set({ isLoading: true });
        try {
          const response = await api.get('/auth/me');
          set({
            user: response.data.data,
            isLoading: false,
          });
        } catch (error) {
          set({ isLoading: false });
          // If unauthorized, logout
          if ((error as any)?.response?.status === 401) {
            get().logout();
          }
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({ token: state.token, user: state.user }),
    }
  )
);