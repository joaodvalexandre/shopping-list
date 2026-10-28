import './bootstrap';
import Iconify from '@iconify/iconify';

// Echo-based real-time listener
window.Echo.channel('models')
    .listen('ModelChanged', (event) => {
        const { model } = event;

        if (['item', 'shopping_list'].includes(model)) {
            setTimeout(() => {
                location.reload();
            }, 1000);
        }
    });
