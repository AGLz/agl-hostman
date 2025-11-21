/**
 * Real-Time Alert Panel Component
 *
 * Example component demonstrating infrastructure alerts
 * Using Laravel Reverb + React Hooks
 *
 * @example
 * <RealtimeAlertPanel severity="critical" />
 */

import React from 'react';
import { useInfrastructureAlerts } from '@/hooks/useWebSocket';

export default function RealtimeAlertPanel({ severity = null, maxAlerts = 10 }) {
    const { alerts, lastAlert, clearAlerts } = useInfrastructureAlerts(
        severity,
        (alert) => {
            console.log(`[RealtimeAlertPanel] New alert:`, alert);

            // Optional: Show browser notification for critical alerts
            if (alert.severity === 'critical' && 'Notification' in window) {
                new Notification(alert.title, {
                    body: alert.message,
                    icon: '/favicon.ico',
                });
            }
        }
    );

    const getSeverityColor = (severity) => {
        switch (severity) {
            case 'critical':
                return 'bg-red-100 border-red-500 text-red-900';
            case 'warning':
                return 'bg-yellow-100 border-yellow-500 text-yellow-900';
            case 'info':
                return 'bg-blue-100 border-blue-500 text-blue-900';
            default:
                return 'bg-gray-100 border-gray-500 text-gray-900';
        }
    };

    const getSeverityIcon = (severity) => {
        switch (severity) {
            case 'critical':
                return '🔴';
            case 'warning':
                return '⚠️';
            case 'info':
                return 'ℹ️';
            default:
                return '📌';
        }
    };

    return (
        <div className="bg-white rounded-lg shadow-lg p-6">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-bold text-gray-900">
                    Infrastructure Alerts
                    {severity && (
                        <span className="ml-2 text-sm font-normal text-gray-600">
                            ({severity})
                        </span>
                    )}
                </h2>
                {alerts.length > 0 && (
                    <button
                        onClick={clearAlerts}
                        className="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
                    >
                        Clear All
                    </button>
                )}
            </div>

            {/* Alert Count */}
            <div className="mb-4 text-sm text-gray-600">
                {alerts.length > 0 ? (
                    <span>
                        Showing {Math.min(alerts.length, maxAlerts)} of{' '}
                        {alerts.length} alert{alerts.length !== 1 ? 's' : ''}
                    </span>
                ) : (
                    <span>No alerts</span>
                )}
            </div>

            {/* Alerts List */}
            <div className="space-y-3 max-h-96 overflow-y-auto">
                {alerts.length > 0 ? (
                    alerts.slice(0, maxAlerts).map((alert, index) => (
                        <div
                            key={index}
                            className={`border-l-4 rounded-lg p-4 transition-all ${getSeverityColor(
                                alert.severity
                            )} ${
                                index === 0 ? 'ring-2 ring-offset-2 ring-blue-500' : ''
                            }`}
                        >
                            {/* Alert Header */}
                            <div className="flex items-start justify-between mb-2">
                                <div className="flex items-center gap-2">
                                    <span className="text-xl">
                                        {getSeverityIcon(alert.severity)}
                                    </span>
                                    <h3 className="font-semibold">
                                        {alert.title}
                                    </h3>
                                </div>
                                <span className="text-xs opacity-75">
                                    {new Date(alert.timestamp).toLocaleTimeString()}
                                </span>
                            </div>

                            {/* Alert Message */}
                            <p className="text-sm mb-2">{alert.message}</p>

                            {/* Alert Metadata */}
                            <div className="flex flex-wrap gap-2 text-xs">
                                <span className="px-2 py-1 bg-white bg-opacity-50 rounded">
                                    {alert.resource_type}
                                </span>
                                <span className="px-2 py-1 bg-white bg-opacity-50 rounded font-mono">
                                    {alert.resource_id}
                                </span>
                            </div>

                            {/* Additional Metadata */}
                            {alert.metadata && Object.keys(alert.metadata).length > 0 && (
                                <details className="mt-2">
                                    <summary className="text-xs cursor-pointer hover:underline">
                                        View Details
                                    </summary>
                                    <pre className="mt-2 text-xs bg-white bg-opacity-50 p-2 rounded overflow-x-auto">
                                        {JSON.stringify(alert.metadata, null, 2)}
                                    </pre>
                                </details>
                            )}
                        </div>
                    ))
                ) : (
                    <div className="text-center py-8 text-gray-500">
                        <div className="text-4xl mb-2">✅</div>
                        <div>No alerts at this time</div>
                        <div className="text-xs mt-1">
                            Real-time monitoring active
                        </div>
                    </div>
                )}
            </div>

            {/* Last Alert Notification */}
            {lastAlert && alerts.length > 0 && (
                <div className="mt-4 pt-4 border-t border-gray-200">
                    <div className="text-xs text-gray-500">
                        Last alert received:{' '}
                        <span className="font-medium text-gray-700">
                            {new Date(lastAlert.timestamp).toLocaleString()}
                        </span>
                    </div>
                </div>
            )}
        </div>
    );
}
