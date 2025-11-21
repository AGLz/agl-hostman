/**
 * Real-Time Server Monitor Component
 *
 * Example component demonstrating WebSocket integration
 * Using Laravel Reverb + React Hooks
 *
 * @example
 * <RealtimeServerMonitor serverCode="AGLSRV1" />
 */

import React from 'react';
import { useServerMetrics, useWebSocket } from '@/hooks/useWebSocket';

export default function RealtimeServerMonitor({ serverCode = 'AGLSRV1' }) {
    const { isConnected, connectionState } = useWebSocket();
    const { metrics, lastUpdate } = useServerMetrics(serverCode, (data) => {
        console.log(`[RealtimeServerMonitor] New metrics for ${serverCode}:`, data);

        // Optional: Show notification on high CPU
        if (data.cpu_usage > 80) {
            console.warn(`High CPU usage on ${serverCode}: ${data.cpu_usage}%`);
        }
    });

    // Connection status indicator
    const connectionStatus = isConnected ? (
        <span className="inline-flex items-center gap-1 text-green-600">
            <span className="w-2 h-2 bg-green-600 rounded-full animate-pulse"></span>
            Connected
        </span>
    ) : (
        <span className="inline-flex items-center gap-1 text-red-600">
            <span className="w-2 h-2 bg-red-600 rounded-full"></span>
            Disconnected
        </span>
    );

    return (
        <div className="bg-white rounded-lg shadow-lg p-6">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-bold text-gray-900">
                    {serverCode} - Real-Time Metrics
                </h2>
                <div className="text-sm">
                    {connectionStatus}
                </div>
            </div>

            {/* Metrics Grid */}
            {metrics ? (
                <div className="grid grid-cols-2 gap-4">
                    {/* CPU Usage */}
                    <div className="bg-gray-50 rounded-lg p-4">
                        <div className="text-sm font-medium text-gray-600 mb-1">
                            CPU Usage
                        </div>
                        <div className="text-3xl font-bold text-gray-900">
                            {metrics.cpu_usage.toFixed(1)}%
                        </div>
                        <div className="mt-2 h-2 bg-gray-200 rounded-full overflow-hidden">
                            <div
                                className={`h-full transition-all duration-300 ${
                                    metrics.cpu_usage > 80
                                        ? 'bg-red-500'
                                        : metrics.cpu_usage > 60
                                        ? 'bg-yellow-500'
                                        : 'bg-green-500'
                                }`}
                                style={{ width: `${metrics.cpu_usage}%` }}
                            />
                        </div>
                    </div>

                    {/* Memory Usage */}
                    <div className="bg-gray-50 rounded-lg p-4">
                        <div className="text-sm font-medium text-gray-600 mb-1">
                            Memory Usage
                        </div>
                        <div className="text-3xl font-bold text-gray-900">
                            {metrics.memory_usage.toFixed(1)}%
                        </div>
                        <div className="mt-2 h-2 bg-gray-200 rounded-full overflow-hidden">
                            <div
                                className={`h-full transition-all duration-300 ${
                                    metrics.memory_usage > 80
                                        ? 'bg-red-500'
                                        : metrics.memory_usage > 60
                                        ? 'bg-yellow-500'
                                        : 'bg-green-500'
                                }`}
                                style={{ width: `${metrics.memory_usage}%` }}
                            />
                        </div>
                    </div>

                    {/* Container Count */}
                    <div className="bg-gray-50 rounded-lg p-4">
                        <div className="text-sm font-medium text-gray-600 mb-1">
                            Containers
                        </div>
                        <div className="text-3xl font-bold text-gray-900">
                            {metrics.container_count}
                        </div>
                        <div className="text-xs text-gray-500 mt-1">
                            {metrics.status === 'online' ? 'Online' : 'Offline'}
                        </div>
                    </div>

                    {/* Uptime */}
                    <div className="bg-gray-50 rounded-lg p-4">
                        <div className="text-sm font-medium text-gray-600 mb-1">
                            Uptime
                        </div>
                        <div className="text-3xl font-bold text-gray-900">
                            {metrics.uptime
                                ? formatUptime(metrics.uptime)
                                : 'N/A'}
                        </div>
                        <div className="text-xs text-gray-500 mt-1">
                            {metrics.uptime ? `${metrics.uptime}s` : ''}
                        </div>
                    </div>
                </div>
            ) : (
                <div className="text-center py-8 text-gray-500">
                    {isConnected
                        ? 'Waiting for metrics...'
                        : 'Connecting to WebSocket...'}
                </div>
            )}

            {/* Network Stats (if available) */}
            {metrics?.network_stats && (
                <div className="mt-4 pt-4 border-t border-gray-200">
                    <h3 className="text-sm font-medium text-gray-600 mb-2">
                        Network Statistics
                    </h3>
                    <div className="grid grid-cols-2 gap-2">
                        <div className="text-sm">
                            <span className="text-gray-600">TX: </span>
                            <span className="font-mono text-gray-900">
                                {formatBytes(metrics.network_stats.tx_bytes)}
                            </span>
                        </div>
                        <div className="text-sm">
                            <span className="text-gray-600">RX: </span>
                            <span className="font-mono text-gray-900">
                                {formatBytes(metrics.network_stats.rx_bytes)}
                            </span>
                        </div>
                    </div>
                </div>
            )}

            {/* Last Update */}
            {lastUpdate && (
                <div className="mt-4 pt-4 border-t border-gray-200 text-xs text-gray-500 text-center">
                    Last updated: {lastUpdate.toLocaleTimeString()}
                    {' · '}
                    Connection: {connectionState}
                </div>
            )}
        </div>
    );
}

/**
 * Format uptime in seconds to human-readable format
 */
function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (days > 0) {
        return `${days}d ${hours}h`;
    } else if (hours > 0) {
        return `${hours}h ${minutes}m`;
    } else {
        return `${minutes}m`;
    }
}

/**
 * Format bytes to human-readable format
 */
function formatBytes(bytes) {
    if (bytes === 0) return '0 B';

    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
}
