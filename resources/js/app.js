import './jquery.min';
import './bootstrap';
import 'laravel-datatables-vite';
import Iconify from '@iconify/iconify';

import $ from 'jquery';
window.$ = window.jQuery = $;

// Echo-based real-time listener
window.Echo.channel('models')
    .listen('ModelChanged', (event) => {
        const { model, action, data } = event;

        if (['item', 'shopping_list'].includes(model)) {
            setTimeout(() => {
                location.reload();
            }, 1000);
        }
    });

