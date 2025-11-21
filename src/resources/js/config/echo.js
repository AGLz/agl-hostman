/**
 * Laravel Echo Configuration
 *
 * Configures WebSocket connection using Laravel Reverb
 */
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

/**
 * Initialize Laravel Echo with Reverb configuration
 */
export const initializeEcho = () => {
    if (window.Echo) {
        return window.Echo;
    }

    window.Echo = new Echo({
        broadcaster: 'reverb',
        key: import.meta.env.VITE_REVERB_APP_KEY,
        wsHost: import.meta.env.VITE_REVERB_HOST || window.location.hostname,
        wsPort: import.meta.env.VITE_REVERB_PORT ?? 8080,
        wssPort: import.meta.env.VITE_REVERB_PORT ?? 8080,
        forceTLS: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https',
        enabledTransports: ['ws', 'wss'],
        disableStats: true,
        encrypted: import.meta.env.VITE_REVERB_SCHEME === 'https',
    });

    return window.Echo;
};

/**
 * Get Echo instance (initialize if needed)
 */
export const getEcho = () => {
    return window.Echo || initializeEcho();
};

/**
 * Disconnect Echo and cleanup
 */
export const disconnectEcho = () => {
    if (window.Echo) {
        window.Echo.disconnect();
        window.Echo = null;
    }
};

export default getEcho;
