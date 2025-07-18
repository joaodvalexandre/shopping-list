import defaultTheme from 'tailwindcss/defaultTheme';
import forms from '@tailwindcss/forms';

/** @type {import('tailwindcss').Config} */
export default {
    darkMode: 'class',
    content: [
        "./resources/**/*.blade.php",
        "./resources/**/*.js",
        "./resources/**/*.css",
    ],

    theme: {
        extend: {
            fontFamily: {
                sans: ['Figtree', ...defaultTheme.fontFamily.sans],
            },
            colors: {
                ...defaultTheme.colors, // Merge Tailwind's default colors
                primaryColor: '#EC6609',    // Company Orange
                secondaryColor: '#000000',  // White
                terciaryColor: '#FFFFFF',   // Black
            },
            screens: {
                'lg': '900px'
            }
        }
    },

    plugins: [forms],
};
