import axios from 'axios';
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.axios = axios;
window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

/**
 * Laravel Echo Configuration
 *
 * Configure Echo to use Reverb for WebSocket connections
 * This enables real-time updates for infrastructure monitoring
 */
window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'reverb',
    key: import.meta.env.VITE_REVERB_APP_KEY,
    wsHost: import.meta.env.VITE_REVERB_HOST,
    wsPort: import.meta.env.VITE_REVERB_PORT ?? 8080,
    wssPort: import.meta.env.VITE_REVERB_PORT ?? 8080,
    forceTLS: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https',
    enabledTransports: ['ws', 'wss'],

    // Reconnection settings
    disableStats: true,
    enableLogging: import.meta.env.DEV,

    // Auth endpoint for private/presence channels
    authEndpoint: '/broadcasting/auth',
    auth: {
        headers: {
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? '',
        },
    },
});

/**
 * Connection Event Handlers
 */
window.Echo.connector.pusher.connection.bind('connected', () => {
    console.log('[Echo] Connected to Reverb WebSocket server');
});

window.Echo.connector.pusher.connection.bind('disconnected', () => {
    console.warn('[Echo] Disconnected from Reverb WebSocket server');
});

window.Echo.connector.pusher.connection.bind('error', (error) => {
    console.error('[Echo] Connection error:', error);
});

window.Echo.connector.pusher.connection.bind('state_change', (states) => {
    console.log('[Echo] Connection state changed:', states.current);
});
