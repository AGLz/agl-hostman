import axios from 'axios';

window.axios = axios;
window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

/**
 * Laravel Echo Configuration (Reverb/WebSocket)
 * Only initialize if VITE_REVERB_APP_KEY is set.
 * This prevents Pusher from crashing when Reverb is not configured.
 */
const reverbKey = import.meta.env.VITE_REVERB_APP_KEY;

if (reverbKey) {
    import('laravel-echo').then(({ default: Echo }) => {
        import('pusher-js').then(({ default: Pusher }) => {
            window.Pusher = Pusher;
            window.Echo = new Echo({
                broadcaster: 'reverb',
                key: reverbKey,
                wsHost: import.meta.env.VITE_REVERB_HOST ?? 'localhost',
                wsPort: import.meta.env.VITE_REVERB_PORT ?? 8080,
                wssPort: import.meta.env.VITE_REVERB_PORT ?? 8080,
                forceTLS: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https',
                enabledTransports: ['ws', 'wss'],
                disableStats: true,
                enableLogging: import.meta.env.DEV,
                authEndpoint: '/broadcasting/auth',
                auth: {
                    headers: {
                        'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? '',
                    },
                },
            });

            window.Echo.connector.pusher.connection.bind('connected', () => {
                console.log('[Echo] Connected to Reverb WebSocket server');
            });

            window.Echo.connector.pusher.connection.bind('disconnected', () => {
                console.warn('[Echo] Disconnected from Reverb WebSocket server');
            });

            window.Echo.connector.pusher.connection.bind('error', (error) => {
                console.error('[Echo] Connection error:', error);
            });
        });
    });
} else {
    window.Echo = null;
}
