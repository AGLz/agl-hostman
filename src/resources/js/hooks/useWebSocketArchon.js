import { useEffect, useState, useCallback } from 'react';

/**
 * Custom hook for WebSocket/Reverb integration (Archon-specific)
 *
 * @param {Object} options - Configuration options
 * @param {Array} options.channels - Array of channel names to subscribe to
 * @param {Object} options.events - Event handlers { 'event.name': (data) => {} }
 * @param {boolean} options.autoConnect - Whether to connect automatically (default: true)
 * @returns {Object} - { isConnected, subscribe, unsubscribe, send }
 */
export function useWebSocket({ channels = [], events = {}, autoConnect = true }) {
    const [isConnected, setIsConnected] = useState(false);
    const [subscriptions, setSubscriptions] = useState(new Map());

    useEffect(() => {
        if (!autoConnect || channels.length === 0) return;

        // Check if Echo is available (Laravel Reverb/Pusher)
        if (typeof window.Echo === 'undefined') {
            console.warn('Echo not initialized. Make sure Laravel Reverb/Pusher is configured.');
            return;
        }

        const newSubscriptions = new Map();

        // Subscribe to channels
        channels.forEach(channelName => {
            const channel = window.Echo.channel(channelName);

            // Bind event handlers
            Object.entries(events).forEach(([eventName, handler]) => {
                channel.listen(eventName, handler);
            });

            newSubscriptions.set(channelName, channel);
        });

        setSubscriptions(newSubscriptions);
        setIsConnected(true);

        // Cleanup
        return () => {
            newSubscriptions.forEach((channel, channelName) => {
                // Unbind all event handlers
                Object.keys(events).forEach(eventName => {
                    channel.stopListening(eventName);
                });

                // Leave channel
                window.Echo.leave(channelName);
            });

            setSubscriptions(new Map());
            setIsConnected(false);
        };
    }, [JSON.stringify(channels), JSON.stringify(Object.keys(events)), autoConnect]);

    const subscribe = useCallback((channelName, eventHandlers) => {
        if (!window.Echo) return;

        const channel = window.Echo.channel(channelName);

        Object.entries(eventHandlers).forEach(([eventName, handler]) => {
            channel.listen(eventName, handler);
        });

        setSubscriptions(prev => new Map(prev).set(channelName, channel));
    }, []);

    const unsubscribe = useCallback((channelName) => {
        if (!window.Echo) return;

        const channel = subscriptions.get(channelName);
        if (channel) {
            window.Echo.leave(channelName);
            setSubscriptions(prev => {
                const newMap = new Map(prev);
                newMap.delete(channelName);
                return newMap;
            });
        }
    }, [subscriptions]);

    const send = useCallback((channelName, eventName, data) => {
        const channel = subscriptions.get(channelName);
        if (channel) {
            channel.whisper(eventName, data);
        }
    }, [subscriptions]);

    return {
        isConnected,
        subscribe,
        unsubscribe,
        send
    };
}
