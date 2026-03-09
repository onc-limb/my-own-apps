import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    target: 'esnext',
  },
  worker: {
    format: 'es',
  },
  optimizeDeps: {
    exclude: ['@jsquash/webp', '@jsquash/avif'],
  },
});
