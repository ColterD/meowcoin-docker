import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/socket.io': {
        target: 'http://localhost:8080',
        ws: true,
      }
    }
  },
  build: {
    rollupOptions: {
      // Disable native module usage
      external: [/@rollup\/rollup-linux-.*/, /@rollup\/rollup-darwin-.*/],
    },
    // Use fewer worker threads to avoid memory issues
    minify: 'terser',
    terserOptions: {
      format: {
        comments: false,
      },
    },
  },
  optimizeDeps: {
    // Skip optimizing certain dependencies that might cause issues
    exclude: ['@rollup/rollup-linux-x64-gnu', '@rollup/rollup-darwin-x64'],
  },
});