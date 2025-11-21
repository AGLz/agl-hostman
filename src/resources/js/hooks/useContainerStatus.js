/**
 * useContainerStatus Hook
 *
 * Real-time container status updates via WebSocket
 */
import { useState, useCallback } from 'react';
import { useWebSocket } from './useWebSocket';

/**
 * Container status WebSocket hook
 *
 * @param {string} vmid - Container VMID to monitor
 * @param {object} options - Additional options
 * @returns {object} Container status and connection state
 */
export const useContainerStatus = (vmid, options = {}) => {
    const [status, setStatus] = useState({
        vmid: vmid,
        name: null,
        status: 'unknown',
        previous_status: null,
        server_code: null,
        metrics: null,
        timestamp: null,
    });

    const [statusHistory, setStatusHistory] = useState([]);
    const { keepHistory = true, onStatusChange } = options;

    const handleStatusUpdate = useCallback((data) => {
        const newStatus = {
            vmid: data.vmid,
            name: data.name,
            status: data.status,
            previous_status: data.previous_status,
            server_code: data.server_code,
            metrics: data.metrics,
            timestamp: data.timestamp,
        };

        setStatus(newStatus);

        // Keep status change history
        if (keepHistory) {
            setStatusHistory((prev) => [
                ...prev,
                {
                    ...newStatus,
                    change: `${data.previous_status} → ${data.status}`,
                },
            ]);
        }

        // Callback for status changes
        if (onStatusChange) {
            onStatusChange(newStatus);
        }
    }, [keepHistory, onStatusChange]);

    const { isConnected, error, lastMessage, disconnect, reconnect } = useWebSocket(
        `infrastructure.container.${vmid}`,
        'container.status.changed',
        handleStatusUpdate,
        options
    );

    const clearHistory = useCallback(() => {
        setStatusHistory([]);
    }, []);

    return {
        status,
        statusHistory,
        isConnected,
        error,
        lastMessage,
        disconnect,
        reconnect,
        clearHistory,
    };
};

export default useContainerStatus;
