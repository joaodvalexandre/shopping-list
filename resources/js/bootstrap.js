import 'bootstrap';

import axios from 'axios';
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.axios = axios;
window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'pusher',
    key: import.meta.env.VITE_PUSHER_APP_KEY,
    cluster: import.meta.env.VITE_PUSHER_APP_CLUSTER,
    forceTLS: true,
});

// Add Axios interceptor to send the current Echo socket ID with every request
axios.interceptors.request.use(config => {
    if (window.Echo && window.Echo.socketId()) {
        config.headers['X-Socket-ID'] = window.Echo.socketId();
    }
    return config;
});
