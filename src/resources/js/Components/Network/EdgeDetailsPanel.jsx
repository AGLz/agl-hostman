import React from 'react';
import { X, Activity, Zap, AlertCircle } from 'lucide-react';

export default function EdgeDetailsPanel({ edge, onClose }) {
    const getConnectionTypeLabel = (type) => {
        switch (type) {
            case 'wireguard':
                return { label: 'WireGuard', color: 'text-green-400' };
            case 'lan':
                return { label: 'LAN', color: 'text-gray-400' };
            case 'tailscale':
                return { label: 'Tailscale', color: 'text-blue-400' };
            default:
                return { label: type, color: 'text-gray-400' };
        }
    };

    const getLatencyStatus = (latencyMs) => {
        if (latencyMs < 20) return { status: 'Excellent', color: 'text-green-400' };
        if (latencyMs < 50) return { status: 'Good', color: 'text-yellow-400' };
        if (latencyMs < 100) return { status: 'Fair', color: 'text-orange-400' };
        return { status: 'Poor', color: 'text-red-400' };
    };

    const connectionType = getConnectionTypeLabel(edge.type);
    const latencyStatus = getLatencyStatus(edge.latency_ms);

    return (
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-96 bg-gray-800 border border-gray-700 rounded-lg shadow-2xl">
            {/* Header */}
            <div className="bg-gray-900 border-b border-gray-700 p-4 flex items-center justify-between rounded-t-lg">
                <div className="flex items-center">
                    <Activity className="w-5 h-5 text-blue-400 mr-2" />
                    <h2 className="text-white font-semibold">Connection Details</h2>
                </div>
                <button
                    onClick={onClose}
                    className="text-gray-400 hover:text-white transition-colors"
                >
                    <X className="w-5 h-5" />
                </button>
            </div>

            {/* Connection Info */}
            <div className="p-4">
                {/* Nodes */}
                <div className="mb-4">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-gray-400 text-sm">Source</span>
                        <code className="text-blue-400 font-semibold">{edge.source}</code>
                    </div>
                    <div className="flex items-center justify-center my-2">
                        <div className="w-full h-0.5 bg-gray-700"></div>
                        <div className="px-2">
                            <Zap className="w-4 h-4 text-yellow-400" />
                        </div>
                        <div className="w-full h-0.5 bg-gray-700"></div>
                    </div>
                    <div className="flex items-center justify-between">
                        <span className="text-gray-400 text-sm">Target</span>
                        <code className="text-purple-400 font-semibold">{edge.target}</code>
                    </div>
                </div>

                {/* Connection Type */}
                <div className="bg-gray-900 p-3 rounded mb-4">
                    <div className="flex items-center justify-between">
                        <span className="text-gray-400 text-sm">Connection Type</span>
                        <span className={`font-semibold ${connectionType.color}`}>
                            {connectionType.label}
                        </span>
                    </div>
                    <div className="flex items-center justify-between mt-2">
                        <span className="text-gray-400 text-sm">Bidirectional</span>
                        <span className="text-white">
                            {edge.bidirectional ? 'Yes' : 'No'}
                        </span>
                    </div>
                </div>

                {/* Performance Metrics */}
                <div className="space-y-3 mb-4">
                    {/* Latency */}
                    <div className="bg-gray-900 p-3 rounded">
                        <div className="flex items-center justify-between mb-2">
                            <span className="text-gray-400 text-sm">Latency</span>
                            <span className={`text-sm font-semibold ${latencyStatus.color}`}>
                                {latencyStatus.status}
                            </span>
                        </div>
                        <div className="flex items-center justify-between">
                            <div className="flex-1">
                                <div className="w-full h-2 bg-gray-700 rounded-full">
                                    <div
                                        className={`h-full rounded-full transition-all ${
                                            edge.latency_ms < 20
                                                ? 'bg-green-500'
                                                : edge.latency_ms < 50
                                                ? 'bg-yellow-500'
                                                : edge.latency_ms < 100
                                                ? 'bg-orange-500'
                                                : 'bg-red-500'
                                        }`}
                                        style={{ width: `${Math.min((edge.latency_ms / 200) * 100, 100)}%` }}
                                    ></div>
                                </div>
                            </div>
                            <span className="text-white font-semibold ml-3">
                                {edge.latency_ms} ms
                            </span>
                        </div>
                    </div>

                    {/* Bandwidth */}
                    <div className="bg-gray-900 p-3 rounded">
                        <div className="flex items-center justify-between">
                            <span className="text-gray-400 text-sm">Bandwidth</span>
                            <span className="text-white font-semibold">
                                {edge.bandwidth_mbps} Mbps
                            </span>
                        </div>
                    </div>

                    {/* Packet Loss */}
                    <div className="bg-gray-900 p-3 rounded">
                        <div className="flex items-center justify-between mb-2">
                            <span className="text-gray-400 text-sm">Packet Loss</span>
                            <span
                                className={`text-sm font-semibold ${
                                    edge.packet_loss_percent < 1
                                        ? 'text-green-400'
                                        : edge.packet_loss_percent < 5
                                        ? 'text-yellow-400'
                                        : 'text-red-400'
                                }`}
                            >
                                {edge.packet_loss_percent}%
                            </span>
                        </div>
                        {edge.packet_loss_percent > 5 && (
                            <div className="flex items-center text-red-400 text-xs">
                                <AlertCircle className="w-3 h-3 mr-1" />
                                <span>High packet loss detected</span>
                            </div>
                        )}
                    </div>
                </div>

                {/* WireGuard Specific */}
                {edge.type === 'wireguard' && edge.last_handshake && (
                    <div className="bg-gray-900 p-3 rounded">
                        <div className="flex items-center justify-between">
                            <span className="text-gray-400 text-sm">Last Handshake</span>
                            <span className="text-white text-sm">
                                {new Date(edge.last_handshake).toLocaleString()}
                            </span>
                        </div>
                    </div>
                )}

                {/* Status */}
                <div className="mt-4 pt-4 border-t border-gray-700">
                    <div className="flex items-center justify-between">
                        <span className="text-gray-400">Connection Status</span>
                        <span
                            className={`px-3 py-1 rounded-full text-xs font-semibold ${
                                edge.status === 'online'
                                    ? 'bg-green-900 text-green-200'
                                    : 'bg-red-900 text-red-200'
                            }`}
                        >
                            {edge.status}
                        </span>
                    </div>
                    <div className="flex items-center justify-between mt-2">
                        <span className="text-gray-400">Health Score</span>
                        <div className="flex items-center">
                            <div className="w-24 h-2 bg-gray-700 rounded-full mr-2">
                                <div
                                    className="h-full rounded-full transition-all"
                                    style={{
                                        width: `${edge.health}%`,
                                        backgroundColor:
                                            edge.health >= 90
                                                ? '#10B981'
                                                : edge.health >= 70
                                                ? '#F59E0B'
                                                : '#EF4444',
                                    }}
                                ></div>
                            </div>
                            <span className="text-white font-semibold">{edge.health}%</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
