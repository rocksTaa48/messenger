import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from "@tailwindcss/vite";
export default defineConfig({
    build: {
        outDir: '../../priv/static',
        emptyOutDir: true,
        assetsDir: 'svelte_assets',
        manifest: true,
        rollupOptions: {
            input: './index.html'
        }
    },

    server: {
        //DEVELOPMENT
        host: true,
        port: 5173,
        strictPort: true,
        // Добавляем разрешение для хоста Cloudflare
        allowedHosts: [
            '679d2efdeebd8ee6-94-140-245-137.serveousercontent.com'
        ],
        hmr: {
            protocol: 'wss',
            host: '679d2efdeebd8ee6-94-140-245-137.serveousercontent.com',
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
