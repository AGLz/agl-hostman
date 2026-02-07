import React, { useState, useEffect } from 'react';
import { useInfrastructureAlerts } from '../hooks/useWebSocket';

/**
 * NotificationBadge Component
 *
 * Displays real-time notification badge with unread count
 * and alert list dropdown
 */
export function NotificationBadge({ severity = null, position = 'top-right' }) {
    const [isOpen, setIsOpen] = useState(false);
    const { alerts, lastAlert, clearAlerts } = useInfrastructureAlerts(severity);

    const unreadCount = alerts.length;
    const hasUnread = unreadCount > 0;

    // Auto-clear old alerts after 24 hours
    useEffect(() => {
        const interval = setInterval(() => {
            const now = Date.now();
            const dayInMs = 24 * 60 * 60 * 1000;

            setAlerts(prev => prev.filter(alert => {
                const alertTime = new Date(alert.timestamp).getTime();
                return now - alertTime < dayInMs;
            }));
        }, 60000); // Check every minute

        return () => clearInterval(interval);
    }, []);

    const getSeverityColor = (severity) => {
        switch (severity) {
            case 'critical':
                return 'bg-red-500';
            case 'warning':
                return 'bg-yellow-500';
            case 'info':
                return 'bg-blue-500';
            default:
                return 'bg-gray-500';
        }
    };

    const getSeverityIcon = (severity) => {
        switch (severity) {
            case 'critical':
                return (
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                    </svg>
                );
            case 'warning':
                return (
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                    </svg>
                );
            case 'info':
                return (
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                    </svg>
                );
            default:
                return (
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z" />
                    </svg>
                );
        }
    };

    const getTimeAgo = (timestamp) => {
        const now = new Date();
        const time = new Date(timestamp);
        const diffMs = now - time;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        return `${diffDays}d ago`;
    };

    const getPositionClasses = () => {
        switch (position) {
            case 'top-left':
                return 'top-4 left-4';
            case 'top-right':
                return 'top-4 right-4';
            case 'bottom-left':
                return 'bottom-4 left-4';
            case 'bottom-right':
                return 'bottom-4 right-4';
            default:
                return 'top-4 right-4';
        }
    };

    const handleMarkAsRead = (alertId) => {
        // Implement mark as read logic
        console.log('Mark as read:', alertId);
    };

    const handleClearAll = () => {
        clearAlerts();
    };

    return (
        <div className={`fixed ${getPositionClasses()} z-50`}>
            <div className="relative">
                {/* Notification button */}
                <button
                    onClick={() => setIsOpen(!isOpen)}
                    className="relative p-2 text-gray-600 hover:text-gray-900 transition-colors"
                    aria-label={`Notifications ${unreadCount > 0 ? `(${unreadCount} unread)` : ''}`}
                >
                    {/* Bell icon */}
                    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
                        />
                    </svg>

                    {/* Badge */}
                    {hasUnread && (
                        <span className="absolute top-0 right-0 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-white transform translate-x-1/4 -translate-y-1/4 bg-red-600 rounded-full">
                            {unreadCount > 99 ? '99+' : unreadCount}
                        </span>
                    )}

                    {/* Live indicator for new alerts */}
                    {lastAlert && isOpen && (
                        <span className="absolute top-0 right-0 w-3 h-3 bg-red-500 rounded-full animate-ping" />
                    )}
                </button>

                {/* Dropdown */}
                {isOpen && (
                    <div className="absolute right-0 mt-2 w-96 bg-white rounded-lg shadow-xl border border-gray-200 z-50">
                        {/* Header */}
                        <div className="px-4 py-3 border-b border-gray-200">
                            <div className="flex items-center justify-between">
                                <h3 className="text-lg font-semibold text-gray-900">
                                    Notifications
                                </h3>
                                {hasUnread && (
                                    <button
                                        onClick={handleClearAll}
                                        className="text-sm text-blue-600 hover:text-blue-800"
                                    >
                                        Clear all
                                    </button>
                                )}
                            </div>
                        </div>

                        {/* Alert list */}
                        <div className="max-h-96 overflow-y-auto">
                            {alerts.length === 0 ? (
                                <div className="px-4 py-8 text-center text-gray-500">
                                    <svg className="mx-auto w-12 h-12 text-gray-400 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path
                                            strokeLinecap="round"
                                            strokeLinejoin="round"
                                            strokeWidth={2}
                                            d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
                                        />
                                    </svg>
                                    <p>No notifications</p>
                                </div>
                            ) : (
                                <ul className="divide-y divide-gray-200">
                                    {alerts.map((alert, index) => (
                                        <li
                                            key={`${alert.resource_id}-${index}`}
                                            className="px-4 py-3 hover:bg-gray-50 transition-colors cursor-pointer"
                                            onClick={() => handleMarkAsRead(alert.resource_id)}
                                        >
                                            <div className="flex items-start space-x-3">
                                                {/* Severity indicator */}
                                                <div className={`flex-shrink-0 w-8 h-8 rounded-full ${getSeverityColor(alert.severity)} flex items-center justify-center text-white`}>
                                                    {getSeverityIcon(alert.severity)}
                                                </div>

                                                {/* Content */}
                                                <div className="flex-1 min-w-0">
                                                    <div className="flex items-center justify-between">
                                                        <p className="text-sm font-medium text-gray-900 truncate">
                                                            {alert.title}
                                                        </p>
                                                        <span className="text-xs text-gray-500 ml-2">
                                                            {getTimeAgo(alert.timestamp)}
                                                        </span>
                                                    </div>
                                                    <p className="text-sm text-gray-600 mt-1">
                                                        {alert.message}
                                                    </p>
                                                    {alert.metadata && (
                                                        <div className="mt-2 text-xs text-gray-500">
                                                            Resource: {alert.resource_type}/{alert.resource_id}
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        </li>
                                    ))}
                                </ul>
                            )}
                        </div>

                        {/* Footer */}
                        {alerts.length > 0 && (
                            <div className="px-4 py-3 border-t border-gray-200">
                                <button
                                    onClick={() => setIsOpen(false)}
                                    className="w-full text-center text-sm text-blue-600 hover:text-blue-800"
                                >
                                    View all notifications
                                </button>
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
}

/**
 * Minimal NotificationBadge Component
 *
 * Smaller version for tight spaces
 */
export function NotificationBadgeMini({ severity = null }) {
    const { alerts } = useInfrastructureAlerts(severity);
    const unreadCount = alerts.length;

    return (
        <div className="relative" title={`${unreadCount} unread notifications`}>
            <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
                />
            </svg>

            {unreadCount > 0 && (
                <span className="absolute -top-1 -right-1 inline-flex items-center justify-center px-1.5 py-0.5 text-xs font-bold leading-none text-white bg-red-600 rounded-full">
                    {unreadCount > 9 ? '9+' : unreadCount}
                </span>
            )}
        </div>
    );
}

export default NotificationBadge;
