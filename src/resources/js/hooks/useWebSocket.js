import { useEffect, useState, useCallback, useRef } from 'react';

/**
 * WebSocket Connection Hook with Exponential Backoff
 *
 * Enhanced hook for subscribing to Laravel Echo channels
 * Handles connection state, automatic reconnection with exponential backoff,
 * message queuing during disconnection, and cleanup
 */
export function useWebSocket(options = {}) {
    const {
        enableReconnect = true,
        reconnectInterval = 1000, // Initial reconnect delay (ms)
        maxReconnectInterval = 30000, // Max reconnect delay (ms)
        reconnectDecay = 1.5, // Exponential backoff multiplier
        maxReconnectAttempts = 10, // Max reconnection attempts
        enableQueue = true, // Queue messages while disconnected
        onReconnect = null, // Callback on successful reconnection
        onDisconnect = null, // Callback on disconnection
    } = options;

    const [isConnected, setIsConnected] = useState(false);
    const [connectionState, setConnectionState] = useState('disconnected');
    const [reconnectAttempts, setReconnectAttempts] = useState(0);
    const [nextReconnectIn, setNextReconnectIn] = useState(null);

    const messageQueueRef = useRef([]);
    const reconnectTimeoutRef = useRef(null);
    const isManualDisconnectRef = useRef(false);

    /**
     * Calculate next reconnect delay with exponential backoff
     */
    const calculateReconnectDelay = useCallback(() => {
        const delay = Math.min(
            reconnectInterval * Math.pow(reconnectDecay, reconnectAttempts),
            maxReconnectInterval
        );
        return Math.floor(delay);
    }, [reconnectInterval, reconnectDecay, maxReconnectInterval, reconnectAttempts]);

    /**
     * Attempt to reconnect with exponential backoff
     */
    const attemptReconnect = useCallback(() => {
        if (!enableReconnect || reconnectAttempts >= maxReconnectAttempts || isManualDisconnectRef.current) {
            return;
        }

        const delay = calculateReconnectDelay();
        setNextReconnectIn(delay);

        console.log(`[useWebSocket] Reconnection attempt ${reconnectAttempts + 1} in ${delay}ms`);

        reconnectTimeoutRef.current = setTimeout(() => {
            setReconnectAttempts(prev => prev + 1);

            // Trigger Echo reconnect
            if (window.Echo && window.Echo.connector) {
                window.Echo.connector.pusher.connection.connect();
            }
        }, delay);
    }, [enableReconnect, reconnectAttempts, maxReconnectAttempts, calculateReconnectDelay]);

    /**
     * Queue message while disconnected
     */
    const queueMessage = useCallback((message) => {
        if (!enableQueue) return false;

        console.log('[useWebSocket] Queueing message:', message);
        messageQueueRef.current.push({
            message,
            timestamp: Date.now()
        });

        // Keep only last 100 messages to prevent memory issues
        if (messageQueueRef.current.length > 100) {
            messageQueueRef.current.shift();
        }

        return true;
    }, [enableQueue]);

    /**
     * Process queued messages after reconnection
     */
    const processQueuedMessages = useCallback(() => {
        if (messageQueueRef.current.length === 0) return [];

        const messages = [...messageQueueRef.current];
        messageQueueRef.current = [];

        console.log(`[useWebSocket] Processing ${messages.length} queued messages`);

        return messages;
    }, []);

    useEffect(() => {
        if (!window.Echo) {
            console.error('[useWebSocket] Echo not initialized');
            return;
        }

        const connection = window.Echo.connector.pusher.connection;

        const handleConnected = () => {
            console.log('[useWebSocket] Connected');
            setIsConnected(true);
            setConnectionState('connected');
            setReconnectAttempts(0);
            setNextReconnectIn(null);

            // Process queued messages
            const queued = processQueuedMessages();
            if (queued.length > 0 && onReconnect) {
                onReconnect(queued);
            }
        };

        const handleDisconnected = () => {
            if (isManualDisconnectRef.current) {
                console.log('[useWebSocket] Manual disconnect');
                setIsConnected(false);
                setConnectionState('disconnected');
                return;
            }

            console.log('[useWebSocket] Disconnected, attempting reconnect...');
            setIsConnected(false);
            setConnectionState('reconnecting');

            if (onDisconnect) {
                onDisconnect();
            }

            // Attempt reconnection
            attemptReconnect();
        };

        const handleError = (error) => {
            console.error('[useWebSocket] Connection error:', error);
            setConnectionState('error');
        };

        const handleStateChange = (states) => {
            console.log('[useWebSocket] State change:', states.current);
            setConnectionState(states.current);
        };

        connection.bind('connected', handleConnected);
        connection.bind('disconnected', handleDisconnected);
        connection.bind('error', handleError);
        connection.bind('state_change', handleStateChange);

        // Set initial state
        setIsConnected(connection.state === 'connected');
        setConnectionState(connection.state);

        return () => {
            connection.unbind('connected', handleConnected);
            connection.unbind('disconnected', handleDisconnected);
            connection.unbind('error', handleError);
            connection.unbind('state_change', handleStateChange);

            // Clear reconnect timeout
            if (reconnectTimeoutRef.current) {
                clearTimeout(reconnectTimeoutRef.current);
            }
        };
    }, [attemptReconnect, processQueuedMessages, onReconnect, onDisconnect]);

    /**
     * Manually disconnect
     */
    const disconnect = useCallback(() => {
        isManualDisconnectRef.current = true;

        if (reconnectTimeoutRef.current) {
            clearTimeout(reconnectTimeoutRef.current);
        }

        if (window.Echo && window.Echo.connector) {
            window.Echo.connector.pusher.connection.disconnect();
        }
    }, []);

    /**
     * Manually reconnect
     */
    const reconnect = useCallback(() => {
        isManualDisconnectRef.current = false;
        setReconnectAttempts(0);

        if (window.Echo && window.Echo.connector) {
            window.Echo.connector.pusher.connection.connect();
        }
    }, []);

    return {
        isConnected,
        connectionState,
        reconnectAttempts,
        nextReconnectIn,
        queueMessage,
        disconnect,
        reconnect,
        isManuallyDisconnected: isManualDisconnectRef.current,
    };
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
    const [error, setError] = useState(null);

    useEffect(() => {
        if (!serverCode || !window.Echo) return;

        const channelName = `infrastructure.server.${serverCode}`;
        console.log(`[useServerMetrics] Subscribing to ${channelName}`);

        try {
            channelRef.current = window.Echo.channel(channelName);

            channelRef.current.listen('.server.metrics.updated', (data) => {
                console.log(`[useServerMetrics] Metrics update for ${serverCode}:`, data);
                setError(null);
                setMetrics(data);
                setLastUpdate(new Date());

                if (onMetricsUpdate) {
                    onMetricsUpdate(data);
                }
            });
        } catch (err) {
            console.error(`[useServerMetrics] Error subscribing to ${channelName}:`, err);
            setError(err);
        }

        return () => {
            if (channelRef.current) {
                console.log(`[useServerMetrics] Leaving channel ${channelName}`);
                window.Echo.leave(channelName);
                channelRef.current = null;
            }
        };
    }, [serverCode, onMetricsUpdate]);

    return { metrics, lastUpdate, error };
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
    const [error, setError] = useState(null);

    useEffect(() => {
        if (!vmid || !window.Echo) return;

        const channelName = `infrastructure.container.${vmid}`;
        console.log(`[useContainerStatus] Subscribing to ${channelName}`);

        try {
            channelRef.current = window.Echo.channel(channelName);

            channelRef.current.listen('.container.status.changed', (data) => {
                console.log(`[useContainerStatus] Status change for ${vmid}:`, data);
                setError(null);
                setStatus(data);
                setLastUpdate(new Date());

                if (onStatusChange) {
                    onStatusChange(data);
                }
            });
        } catch (err) {
            console.error(`[useContainerStatus] Error subscribing to ${channelName}:`, err);
            setError(err);
        }

        return () => {
            if (channelRef.current) {
                console.log(`[useContainerStatus] Leaving channel ${channelName}`);
                window.Echo.leave(channelName);
                channelRef.current = null;
            }
        };
    }, [vmid, onStatusChange]);

    return { status, lastUpdate, error };
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
    const [error, setError] = useState(null);

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

        try {
            channelRef.current = window.Echo.channel(channelName);

            channelRef.current.listen('.alert.triggered', (data) => {
                console.log(`[useInfrastructureAlerts] Alert received:`, data);
                setError(null);
                addAlert(data);
            });
        } catch (err) {
            console.error(`[useInfrastructureAlerts] Error subscribing to ${channelName}:`, err);
            setError(err);
        }

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

    return { alerts, lastAlert, clearAlerts, error };
}

/**
 * Deployment Progress Subscription Hook
 *
 * Subscribes to real-time deployment progress updates
 * @param {string} deploymentId - The deployment ID to monitor
 * @param {function} onProgress - Callback when progress updates
 */
export function useDeploymentProgress(deploymentId, onProgress) {
    const channelRef = useRef(null);
    const [progress, setProgress] = useState(null);
    const [lastUpdate, setLastUpdate] = useState(null);
    const [error, setError] = useState(null);

    useEffect(() => {
        if (!deploymentId || !window.Echo) return;

        const channelName = `deployments.${deploymentId}`;
        console.log(`[useDeploymentProgress] Subscribing to ${channelName}`);

        try {
            channelRef.current = window.Echo.channel(channelName);

            channelRef.current.listen('.deployment.progress.updated', (data) => {
                console.log(`[useDeploymentProgress] Progress update for ${deploymentId}:`, data);
                setError(null);
                setProgress(data);
                setLastUpdate(new Date());

                if (onProgress) {
                    onProgress(data);
                }
            });
        } catch (err) {
            console.error(`[useDeploymentProgress] Error subscribing to ${channelName}:`, err);
            setError(err);
        }

        return () => {
            if (channelRef.current) {
                console.log(`[useDeploymentProgress] Leaving channel ${channelName}`);
                window.Echo.leave(channelName);
                channelRef.current = null;
            }
        };
    }, [deploymentId, onProgress]);

    return { progress, lastUpdate, error };
}

/**
 * System Monitoring Subscription Hook
 *
 * Subscribes to system-wide metrics and health updates
 * @param {function} onMetricsUpdate - Callback when metrics update
 */
export function useSystemMonitoring(onMetricsUpdate) {
    const channelRef = useRef(null);
    const [metrics, setMetrics] = useState(null);
    const [lastUpdate, setLastUpdate] = useState(null);
    const [error, setError] = useState(null);

    useEffect(() => {
        if (!window.Echo) return;

        const channelName = 'system.monitoring';
        console.log(`[useSystemMonitoring] Subscribing to ${channelName}`);

        try {
            channelRef.current = window.Echo.channel(channelName);

            channelRef.current.listen('.system.metrics.updated', (data) => {
                console.log(`[useSystemMonitoring] System metrics updated:`, data);
                setError(null);
                setMetrics(data);
                setLastUpdate(new Date());

                if (onMetricsUpdate) {
                    onMetricsUpdate(data);
                }
            });
        } catch (err) {
            console.error(`[useSystemMonitoring] Error subscribing to ${channelName}:`, err);
            setError(err);
        }

        return () => {
            if (channelRef.current) {
                console.log(`[useSystemMonitoring] Leaving channel ${channelName}`);
                window.Echo.leave(channelName);
                channelRef.current = null;
            }
        };
    }, [onMetricsUpdate]);

    return { metrics, lastUpdate, error };
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
    const [errors, setErrors] = useState({});
    const channelsRef = useRef({});

    useEffect(() => {
        if (!serverCodes.length || !window.Echo) return;

        serverCodes.forEach(serverCode => {
            const channelName = `infrastructure.server.${serverCode}`;

            if (!channelsRef.current[serverCode]) {
                console.log(`[useMultiServerMetrics] Subscribing to ${channelName}`);

                try {
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

                        // Clear error for this server
                        setErrors(prev => {
                            const newErrors = { ...prev };
                            delete newErrors[serverCode];
                            return newErrors;
                        });

                        if (onMetricsUpdate) {
                            onMetricsUpdate(serverCode, data);
                        }
                    });
                } catch (err) {
                    console.error(`[useMultiServerMetrics] Error subscribing to ${channelName}:`, err);
                    setErrors(prev => ({
                        ...prev,
                        [serverCode]: err
                    }));
                }
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

    return { metricsMap, errors };
}
