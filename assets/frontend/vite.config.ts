import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from "@tailwindcss/vite";

// https://vite.dev/config/
export default defineConfig({
  build: {
          outDir: '../../priv/static',
          emptyOutDir: false,
          assetsDir: 'svelte_assets',
          manifest: true,
          rollupOptions: {
          input: './src/main.js'
        }
  },

  server: {
          //DEVELOPMENT
          host: true,
          port: 5173,
          strictPort: true,
          // Добавляем разрешение для хоста Cloudflare
          allowedHosts: [
                  'ff60b077f387f5ad-94-140-245-137.serveousercontent.com'
          ],
          hmr: {
                  protocol: 'wss',
                  host: 'ff60b077f387f5ad-94-140-245-137.serveousercontent.com',
                  clientPort: 443
          },
          // DEVELOPMENT
          proxy: {
                  '/socket': { target: 'ws://localhost:4000', ws: true },
                  '/api': 'http://localhost:4000'
          }
  },
  plugins: [
          svelte(),
          tailwindcss()
  ],
})
