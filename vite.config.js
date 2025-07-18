import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/js/app.js',  // Your main JS file
                'resources/css/app.css', // Your CSS file
            ],
            refresh: true,
        }),
    ],
});
