import { useEffect, useState, useCallback, useRef } from 'react';

/**
 * WebSocket Connection Hook
 *
 * Generic hook for subscribing to Laravel Echo channels
 * Handles connection state, reconnection, and cleanup
 */
export function useWebSocket() {
    const [isConnected, setIsConnected] = useState(false);
    const [connectionState, setConnectionState] = useState('disconnected');

    useEffect(() => {
        if (!window.Echo) {
            console.error('[useWebSocket] Echo not initialized');
            return;
        }

        const connection = window.Echo.connector.pusher.connection;

        const handleConnected = () => {
            setIsConnected(true);
            setConnectionState('connected');
        };

        const handleDisconnected = () => {
            setIsConnected(false);
            setConnectionState('disconnected');
        };

        const handleStateChange = (states) => {
            setConnectionState(states.current);
        };

        connection.bind('connected', handleConnected);
        connection.bind('disconnected', handleDisconnected);
        connection.bind('state_change', handleStateChange);

        // Set initial state
        setIsConnected(connection.state === 'connected');
        setConnectionState(connection.state);

        return () => {
            connection.unbind('connected', handleConnected);
            connection.unbind('disconnected', handleDisconnected);
            connection.unbind('state_change', handleStateChange);
        };
    }, []);

    return { isConnected, connectionState };
}

/**
 * Server Metrics Subscription Hook
 *
 * Subscribes to real-time server metrics updates
 * @param {string} serverCode - The server code to monitor (e.g., 'AGLSRV1')
 * @param {function} onMetricsUpdate - Callback when metrics are updated
 */
export function useServerMetrics(serverCode, onMetricsUpdate) {
    const channelRef = useRef(null);
    const [metrics, setMetrics] = useState(null);
    const [lastUpdate, setLastUpdate] = useState(null);

    useEffect(() => {
        if (!serverCode || !window.Echo) return;

        const channelName = `infrastructure.server.${serverCode}`;
        console.log(`[useServerMetrics] Subscribing to ${channelName}`);

        channelRef.current = window.Echo.channel(channelName);

        channelRef.current.listen('.server.metrics.updated', (data) => {
            console.log(`[useServerMetrics] Metrics update for ${serverCode}:`, data);
            setMetrics(data);
            setLastUpdate(new Date());

            if (onMetricsUpdate) {
                onMetricsUpdate(data);
            }
        });

        return () => {
            if (channelRef.current) {
                console.log(`[useServerMetrics] Leaving channel ${channelName}`);
                window.Echo.leave(channelName);
                channelRef.current = null;
            }
        };
    }, [serverCode, onMetricsUpdate]);

    return { metrics, lastUpdate };
}

/**
 * Container Status Subscription Hook
 *
 * Subscribes to real-time container status changes
 * @param {string} vmid - The container VMID to monitor
 * @param {function} onStatusChange - Callback when status changes
 */
export function useContainerStatus(vmid, onStatusChange) {
    const channelRef = useRef(null);
    const [status, setStatus] = useState(null);
    const [lastUpdate, setLastUpdate] = useState(null);

    useEffect(() => {
        if (!vmid || !window.Echo) return;

        const channelName = `infrastructure.container.${vmid}`;
        console.log(`[useContainerStatus] Subscribing to ${channelName}`);

        channelRef.current = window.Echo.channel(channelName);

        channelRef.current.listen('.container.status.changed', (data) => {
            console.log(`[useContainerStatus] Status change for ${vmid}:`, data);
            setStatus(data);
            setLastUpdate(new Date());

            if (onStatusChange) {
                onStatusChange(data);
            }
        });

        return () => {
            if (channelRef.current) {
                console.log(`[useContainerStatus] Leaving channel ${channelName}`);
                window.Echo.leave(channelName);
                channelRef.current = null;
            }
        };
    }, [vmid, onStatusChange]);

    return { status, lastUpdate };
}

/**
 * Infrastructure Alerts Subscription Hook
 *
 * Subscribes to real-time infrastructure alerts
 * @param {string|null} severity - Filter by severity (null for all alerts)
 * @param {function} onAlert - Callback when alert is triggered
 */
export function useInfrastructureAlerts(severity = null, onAlert) {
    const channelRef = useRef(null);
    const [alerts, setAlerts] = useState([]);
    const [lastAlert, setLastAlert] = useState(null);

    const addAlert = useCallback((alert) => {
        setAlerts(prev => [alert, ...prev].slice(0, 50)); // Keep last 50 alerts
        setLastAlert(alert);

        if (onAlert) {
            onAlert(alert);
        }
    }, [onAlert]);

    useEffect(() => {
        if (!window.Echo) return;

        const channelName = severity
            ? `infrastructure.alerts.${severity}`
            : 'infrastructure.alerts';

        console.log(`[useInfrastructureAlerts] Subscribing to ${channelName}`);

        channelRef.current = window.Echo.channel(channelName);

        channelRef.current.listen('.alert.triggered', (data) => {
            console.log(`[useInfrastructureAlerts] Alert received:`, data);
            addAlert(data);
        });

        return () => {
            if (channelRef.current) {
                console.log(`[useInfrastructureAlerts] Leaving channel ${channelName}`);
                window.Echo.leave(channelName);
                channelRef.current = null;
            }
        };
    }, [severity, addAlert]);

    const clearAlerts = useCallback(() => {
        setAlerts([]);
        setLastAlert(null);
    }, []);

    return { alerts, lastAlert, clearAlerts };
}

/**
 * Multi-Server Metrics Hook
 *
 * Subscribes to multiple servers' metrics simultaneously
 * @param {string[]} serverCodes - Array of server codes to monitor
 * @param {function} onMetricsUpdate - Callback when any server's metrics update
 */
export function useMultiServerMetrics(serverCodes = [], onMetricsUpdate) {
    const [metricsMap, setMetricsMap] = useState({});
    const channelsRef = useRef({});

    useEffect(() => {
        if (!serverCodes.length || !window.Echo) return;

        serverCodes.forEach(serverCode => {
            const channelName = `infrastructure.server.${serverCode}`;

            if (!channelsRef.current[serverCode]) {
                console.log(`[useMultiServerMetrics] Subscribing to ${channelName}`);

                channelsRef.current[serverCode] = window.Echo.channel(channelName);

                channelsRef.current[serverCode].listen('.server.metrics.updated', (data) => {
                    console.log(`[useMultiServerMetrics] Metrics for ${serverCode}:`, data);

                    setMetricsMap(prev => ({
                        ...prev,
                        [serverCode]: {
                            ...data,
                            lastUpdate: new Date(),
                        }
                    }));

                    if (onMetricsUpdate) {
                        onMetricsUpdate(serverCode, data);
                    }
                });
            }
        });

        return () => {
            Object.entries(channelsRef.current).forEach(([serverCode, channel]) => {
                const channelName = `infrastructure.server.${serverCode}`;
                console.log(`[useMultiServerMetrics] Leaving channel ${channelName}`);
                window.Echo.leave(channelName);
            });
            channelsRef.current = {};
        };
    }, [serverCodes.join(','), onMetricsUpdate]);

    return metricsMap;
}
