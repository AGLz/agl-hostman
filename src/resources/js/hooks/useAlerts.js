/**
 * useAlerts Hook
 *
 * Real-time infrastructure alerts via WebSocket
 */
import { useState, useCallback } from 'react';
import { useWebSocket } from './useWebSocket';

/**
 * Infrastructure alerts WebSocket hook
 *
 * @param {string} severity - Alert severity filter (optional: 'info', 'warning', 'critical')
 * @param {object} options - Additional options
 * @returns {object} Alerts and connection state
 */
export const useAlerts = (severity = null, options = {}) => {
    const [alerts, setAlerts] = useState([]);
    const [unreadCount, setUnreadCount] = useState(0);
    const { maxAlerts = 50, onNewAlert } = options;

    const channelName = severity
        ? `infrastructure.alerts.${severity}`
        : 'infrastructure.alerts';

    const handleNewAlert = useCallback((data) => {
        const newAlert = {
            id: `alert-${Date.now()}-${Math.random()}`,
            severity: data.severity,
            title: data.title,
            message: data.message,
            resource_type: data.resource_type,
            resource_id: data.resource_id,
            metadata: data.metadata,
            timestamp: data.timestamp,
            read: false,
        };

        setAlerts((prev) => {
            const updated = [newAlert, ...prev];
            return updated.slice(0, maxAlerts);
        });

        setUnreadCount((prev) => prev + 1);

        // Callback for new alerts
        if (onNewAlert) {
            onNewAlert(newAlert);
        }

        // Browser notification for critical alerts
        if (data.severity === 'critical' && 'Notification' in window) {
            if (Notification.permission === 'granted') {
                new Notification(data.title, {
                    body: data.message,
                    icon: '/icon-alert.png',
                    tag: newAlert.id,
                });
            }
        }
    }, [maxAlerts, onNewAlert]);

    const { isConnected, error, lastMessage, disconnect, reconnect } = useWebSocket(
        channelName,
        'alert.triggered',
        handleNewAlert,
        options
    );

    const markAsRead = useCallback((alertId) => {
        setAlerts((prev) =>
            prev.map((alert) =>
                alert.id === alertId ? { ...alert, read: true } : alert
            )
        );
        setUnreadCount((prev) => Math.max(0, prev - 1));
    }, []);

    const markAllAsRead = useCallback(() => {
        setAlerts((prev) =>
            prev.map((alert) => ({ ...alert, read: true }))
        );
        setUnreadCount(0);
    }, []);

    const clearAlerts = useCallback(() => {
        setAlerts([]);
        setUnreadCount(0);
    }, []);

    const dismissAlert = useCallback((alertId) => {
        setAlerts((prev) => prev.filter((alert) => alert.id !== alertId));
        setUnreadCount((prev) => {
            const alert = alerts.find((a) => a.id === alertId);
            return alert && !alert.read ? Math.max(0, prev - 1) : prev;
        });
    }, [alerts]);

    return {
        alerts,
        unreadCount,
        isConnected,
        error,
        lastMessage,
        markAsRead,
        markAllAsRead,
        clearAlerts,
        dismissAlert,
        disconnect,
        reconnect,
    };
};

export default useAlerts;
