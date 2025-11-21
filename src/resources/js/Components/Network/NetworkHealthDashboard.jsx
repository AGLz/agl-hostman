import React from 'react';
import { Activity, AlertTriangle, Server, Wifi, TrendingUp } from 'lucide-react';

export default function NetworkHealthDashboard({ health, issues, loading }) {
    if (loading) {
        return (
            <div className="bg-gray-900 border-b border-gray-700 p-4">
                <div className="animate-pulse flex space-x-4">
                    <div className="h-4 bg-gray-700 rounded w-1/4"></div>
                    <div className="h-4 bg-gray-700 rounded w-1/4"></div>
                    <div className="h-4 bg-gray-700 rounded w-1/4"></div>
                    <div className="h-4 bg-gray-700 rounded w-1/4"></div>
                </div>
            </div>
        );
    }

    if (!health) return null;

    const criticalIssues = issues?.filter((i) => i.severity === 'critical') || [];
    const warningIssues = issues?.filter((i) => i.severity === 'warning') || [];

    return (
        <div className="bg-gray-900 border-b border-gray-700">
            {/* Top Metrics */}
            <div className="p-4 grid grid-cols-4 gap-4">
                {/* Total Nodes */}
                <div className="bg-gray-800 p-4 rounded-lg">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-gray-400 text-sm">Total Nodes</span>
                        <Server className="w-5 h-5 text-blue-400" />
                    </div>
                    <div className="flex items-baseline">
                        <span className="text-2xl font-bold text-white">
                            {health.online_nodes}
                        </span>
                        <span className="text-gray-500 ml-1">/ {health.total_nodes}</span>
                    </div>
                    {health.offline_nodes > 0 && (
                        <div className="mt-1 text-xs text-red-400">
                            {health.offline_nodes} offline
                        </div>
                    )}
                </div>

                {/* Average Latency */}
                <div className="bg-gray-800 p-4 rounded-lg">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-gray-400 text-sm">Avg Latency</span>
                        <Activity className="w-5 h-5 text-green-400" />
                    </div>
                    <div className="flex items-baseline">
                        <span className="text-2xl font-bold text-white">
                            {health.avg_latency_ms}
                        </span>
                        <span className="text-gray-500 ml-1">ms</span>
                    </div>
                    <div className="mt-1 text-xs text-gray-500">
                        {health.avg_latency_ms < 30 ? 'Excellent' : health.avg_latency_ms < 60 ? 'Good' : 'Fair'}
                    </div>
                </div>

                {/* Network Health Score */}
                <div className="bg-gray-800 p-4 rounded-lg">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-gray-400 text-sm">Health Score</span>
                        <TrendingUp className="w-5 h-5 text-purple-400" />
                    </div>
                    <div className="flex items-baseline">
                        <span className="text-2xl font-bold text-white">
                            {health.network_health_score}
                        </span>
                        <span className="text-gray-500 ml-1">%</span>
                    </div>
                    <div className="w-full h-1.5 bg-gray-700 rounded-full mt-2">
                        <div
                            className="h-full rounded-full transition-all"
                            style={{
                                width: `${health.network_health_score}%`,
                                backgroundColor:
                                    health.network_health_score >= 90
                                        ? '#10B981'
                                        : health.network_health_score >= 70
                                        ? '#F59E0B'
                                        : '#EF4444',
                            }}
                        ></div>
                    </div>
                </div>

                {/* Active Connections */}
                <div className="bg-gray-800 p-4 rounded-lg">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-gray-400 text-sm">Connections</span>
                        <Wifi className="w-5 h-5 text-yellow-400" />
                    </div>
                    <div className="flex items-baseline">
                        <span className="text-2xl font-bold text-white">
                            {health.healthy_edges}
                        </span>
                        <span className="text-gray-500 ml-1">/ {health.total_edges}</span>
                    </div>
                    {health.degraded_edges > 0 && (
                        <div className="mt-1 text-xs text-yellow-400">
                            {health.degraded_edges} degraded
                        </div>
                    )}
                </div>
            </div>

            {/* Issues Panel */}
            {issues && issues.length > 0 && (
                <div className="border-t border-gray-700 px-4 py-3 bg-gray-850">
                    <div className="flex items-center mb-2">
                        <AlertTriangle className="w-4 h-4 text-orange-400 mr-2" />
                        <h3 className="text-white font-semibold">Network Issues</h3>
                        <span className="ml-2 px-2 py-0.5 bg-red-900 text-red-200 text-xs rounded-full">
                            {issues.length}
                        </span>
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2 max-h-24 overflow-y-auto">
                        {criticalIssues.map((issue, idx) => (
                            <div
                                key={idx}
                                className="bg-red-900/20 border border-red-700 p-2 rounded text-xs"
                            >
                                <div className="flex items-center">
                                    <span className="w-2 h-2 bg-red-500 rounded-full mr-2"></span>
                                    <span className="text-red-300 font-semibold">Critical</span>
                                </div>
                                <p className="text-red-200 mt-1">{issue.message}</p>
                            </div>
                        ))}
                        {warningIssues.map((issue, idx) => (
                            <div
                                key={idx}
                                className="bg-yellow-900/20 border border-yellow-700 p-2 rounded text-xs"
                            >
                                <div className="flex items-center">
                                    <span className="w-2 h-2 bg-yellow-500 rounded-full mr-2"></span>
                                    <span className="text-yellow-300 font-semibold">Warning</span>
                                </div>
                                <p className="text-yellow-200 mt-1">{issue.message}</p>
                            </div>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
}
