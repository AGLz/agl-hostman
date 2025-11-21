/**
 * AlertNotifications Component (Example Implementation)
 *
 * Real-time alert notifications with WebSocket updates
 */
import React, { useEffect } from 'react';
import { useAlerts } from '../hooks/useAlerts';

export const AlertNotifications = () => {
    const {
        alerts,
        unreadCount,
        isConnected,
        markAsRead,
        markAllAsRead,
        dismissAlert,
    } = useAlerts(null, {
        maxAlerts: 50,
        autoConnect: true,
        onNewAlert: (alert) => {
            console.log('New alert received:', alert);
        },
    });

    // Request notification permission on mount
    useEffect(() => {
        if ('Notification' in window && Notification.permission === 'default') {
            Notification.requestPermission();
        }
    }, []);

    // Alert severity styling
    const getSeverityStyle = (severity) => {
        switch (severity) {
            case 'critical':
                return 'bg-red-100 border-red-500 text-red-800';
            case 'warning':
                return 'bg-yellow-100 border-yellow-500 text-yellow-800';
            case 'info':
                return 'bg-blue-100 border-blue-500 text-blue-800';
            default:
                return 'bg-gray-100 border-gray-500 text-gray-800';
        }
    };

    const getSeverityIcon = (severity) => {
        switch (severity) {
            case 'critical':
                return '🚨';
            case 'warning':
                return '⚠️';
            case 'info':
                return 'ℹ️';
            default:
                return '📢';
        }
    };

    return (
        <div className="fixed top-4 right-4 w-96 max-h-screen overflow-y-auto z-50">
            {/* Header */}
            <div className="bg-white rounded-lg shadow-lg mb-2 p-4">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <h3 className="font-semibold">Alerts</h3>
                        {unreadCount > 0 && (
                            <span className="bg-red-500 text-white text-xs px-2 py-1 rounded-full">
                                {unreadCount}
                            </span>
                        )}
                        <span
                            className={`h-2 w-2 rounded-full ${
                                isConnected ? 'bg-green-500' : 'bg-red-500'
                            }`}
                            title={isConnected ? 'Connected' : 'Disconnected'}
                        />
                    </div>
                    {alerts.length > 0 && (
                        <button
                            onClick={markAllAsRead}
                            className="text-sm text-blue-600 hover:underline"
                        >
                            Mark all read
                        </button>
                    )}
                </div>
            </div>

            {/* Alert List */}
            <div className="space-y-2">
                {alerts.length === 0 ? (
                    <div className="bg-white rounded-lg shadow p-4 text-center text-gray-500">
                        No alerts
                    </div>
                ) : (
                    alerts.map((alert) => (
                        <div
                            key={alert.id}
                            className={`rounded-lg shadow-lg p-4 border-l-4 ${getSeverityStyle(
                                alert.severity
                            )} ${alert.read ? 'opacity-60' : ''}`}
                        >
                            <div className="flex items-start justify-between">
                                <div className="flex-1">
                                    <div className="flex items-center gap-2 mb-1">
                                        <span className="text-lg">
                                            {getSeverityIcon(alert.severity)}
                                        </span>
                                        <h4 className="font-semibold">{alert.title}</h4>
                                    </div>
                                    <p className="text-sm mb-2">{alert.message}</p>
                                    <div className="flex items-center gap-4 text-xs">
                                        <span>
                                            {alert.resource_type}: {alert.resource_id}
                                        </span>
                                        <span className="text-gray-500">
                                            {new Date(alert.timestamp).toLocaleTimeString()}
                                        </span>
                                    </div>
                                </div>
                                <button
                                    onClick={() => dismissAlert(alert.id)}
                                    className="ml-2 text-gray-400 hover:text-gray-600"
                                >
                                    ✕
                                </button>
                            </div>
                            {!alert.read && (
                                <button
                                    onClick={() => markAsRead(alert.id)}
                                    className="mt-2 text-xs text-blue-600 hover:underline"
                                >
                                    Mark as read
                                </button>
                            )}
                        </div>
                    ))
                )}
            </div>
        </div>
    );
};

export default AlertNotifications;
