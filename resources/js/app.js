import './bootstrap';
import Iconify from '@iconify/iconify';

// Realtime: reload when something in the family's lists changes.
// The channel is private (authorised per family) and carries only ids.
if (window.familyId) {
    window.Echo.private(`family.${window.familyId}`)
        .listen('ModelChanged', (event) => {
            if (['item', 'shopping_list'].includes(event.model)) {
                setTimeout(() => {
                    location.reload();
                }, 1000);
            }
        });
}
