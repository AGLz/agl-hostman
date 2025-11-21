/**
 * useServerMetrics Hook
 *
 * Real-time server metrics updates via WebSocket
 */
import { useState, useCallback } from 'react';
import { useWebSocket } from './useWebSocket';

/**
 * Server metrics WebSocket hook
 *
 * @param {string} serverCode - Server code to monitor (e.g., 'AGLSRV1')
 * @param {object} options - Additional options
 * @returns {object} Server metrics and connection state
 */
export const useServerMetrics = (serverCode, options = {}) => {
    const [metrics, setMetrics] = useState({
        cpu_usage: 0,
        memory_usage: 0,
        container_count: 0,
        status: 'unknown',
        uptime: null,
        network_stats: null,
        timestamp: null,
    });

    const [metricsHistory, setMetricsHistory] = useState([]);
    const { keepHistory = false, maxHistorySize = 60 } = options;

    const handleMetricsUpdate = useCallback((data) => {
        const newMetrics = {
            cpu_usage: data.cpu_usage,
            memory_usage: data.memory_usage,
            container_count: data.container_count,
            status: data.status,
            uptime: data.uptime,
            network_stats: data.network_stats,
            timestamp: data.timestamp,
        };

        setMetrics(newMetrics);

        // Keep metrics history for charting
        if (keepHistory) {
            setMetricsHistory((prev) => {
                const updated = [...prev, newMetrics];
                // Keep only last N entries
                return updated.slice(-maxHistorySize);
            });
        }
    }, [keepHistory, maxHistorySize]);

    const { isConnected, error, lastMessage, disconnect, reconnect } = useWebSocket(
        `infrastructure.server.${serverCode}`,
        'server.metrics.updated',
        handleMetricsUpdate,
        options
    );

    const clearHistory = useCallback(() => {
        setMetricsHistory([]);
    }, []);

    return {
        metrics,
        metricsHistory,
        isConnected,
        error,
        lastMessage,
        disconnect,
        reconnect,
        clearHistory,
    };
};

export default useServerMetrics;
