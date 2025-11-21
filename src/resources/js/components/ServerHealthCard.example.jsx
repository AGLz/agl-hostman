/**
 * ServerHealthCard Component (Example Implementation)
 *
 * Real-time server health monitoring with WebSocket updates
 */
import React from 'react';
import { useServerMetrics } from '../hooks/useServerMetrics';

export const ServerHealthCard = ({ serverCode }) => {
    const {
        metrics,
        metricsHistory,
        isConnected,
        error,
    } = useServerMetrics(serverCode, {
        keepHistory: true,
        maxHistorySize: 60, // Last 60 data points for charts
        autoConnect: true,
    });

    // Status indicator color
    const getStatusColor = (status) => {
        switch (status) {
            case 'online': return 'text-green-600';
            case 'warning': return 'text-yellow-600';
            case 'offline': return 'text-red-600';
            default: return 'text-gray-400';
        }
    };

    // Format uptime
    const formatUptime = (seconds) => {
        if (!seconds) return 'N/A';
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        return `${days}d ${hours}h`;
    };

    return (
        <div className="bg-white rounded-lg shadow p-6">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold">{serverCode}</h3>
                <div className="flex items-center gap-2">
                    {/* WebSocket Connection Indicator */}
                    <span
                        className={`h-2 w-2 rounded-full ${
                            isConnected ? 'bg-green-500' : 'bg-red-500'
                        }`}
                        title={isConnected ? 'Connected' : 'Disconnected'}
                    />
                    {/* Status Badge */}
                    <span className={`font-medium ${getStatusColor(metrics.status)}`}>
                        {metrics.status.toUpperCase()}
                    </span>
                </div>
            </div>

            {/* Error Display */}
            {error && (
                <div className="mb-4 p-3 bg-red-50 text-red-700 rounded text-sm">
                    WebSocket Error: {error.message || 'Connection failed'}
                </div>
            )}

            {/* Metrics Grid */}
            <div className="grid grid-cols-2 gap-4 mb-4">
                {/* CPU Usage */}
                <div>
                    <p className="text-sm text-gray-500">CPU Usage</p>
                    <p className="text-2xl font-bold">
                        {metrics.cpu_usage.toFixed(1)}%
                    </p>
                    <div className="mt-1 w-full bg-gray-200 rounded-full h-2">
                        <div
                            className={`h-2 rounded-full transition-all ${
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
                <div>
                    <p className="text-sm text-gray-500">Memory Usage</p>
                    <p className="text-2xl font-bold">
                        {metrics.memory_usage.toFixed(1)}%
                    </p>
                    <div className="mt-1 w-full bg-gray-200 rounded-full h-2">
                        <div
                            className={`h-2 rounded-full transition-all ${
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
            </div>

            {/* Additional Stats */}
            <div className="grid grid-cols-2 gap-4 text-sm border-t pt-4">
                <div>
                    <p className="text-gray-500">Containers</p>
                    <p className="font-semibold">{metrics.container_count}</p>
                </div>
                <div>
                    <p className="text-gray-500">Uptime</p>
                    <p className="font-semibold">{formatUptime(metrics.uptime)}</p>
                </div>
            </div>

            {/* Last Updated */}
            <div className="mt-4 text-xs text-gray-400 text-center">
                Last updated: {
                    metrics.timestamp
                        ? new Date(metrics.timestamp).toLocaleTimeString()
                        : 'Never'
                }
            </div>
        </div>
    );
};

export default ServerHealthCard;
