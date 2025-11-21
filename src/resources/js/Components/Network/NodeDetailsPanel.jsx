import React from 'react';
import { useNodeMetrics } from '../../hooks/useNetworkTopology';
import { X, Server, Activity, HardDrive, Network, Terminal } from 'lucide-react';

export default function NodeDetailsPanel({ node, onClose }) {
    const { metrics, loading } = useNodeMetrics(node.id);

    const handleSSH = () => {
        const ip = node.ips?.wireguard || node.ips?.lan || node.ips?.tailscale;
        if (ip) {
            // This would open a WebSSH terminal in production
            alert(`SSH to ${ip} (WebSSH integration coming soon)`);
        }
    };

    const handleMonitor = () => {
        alert(`Opening monitoring dashboard for ${node.name}`);
    };

    const handleRestart = () => {
        if (confirm(`Are you sure you want to restart ${node.name}?`)) {
            alert('Restart functionality coming soon');
        }
    };

    return (
        <div className="absolute right-0 top-0 bottom-0 w-96 bg-gray-800 border-l border-gray-700 shadow-2xl overflow-y-auto">
            {/* Header */}
            <div className="sticky top-0 bg-gray-900 border-b border-gray-700 p-4 flex items-center justify-between">
                <div className="flex items-center">
                    {node.type === 'server' && <Server className="w-5 h-5 text-purple-400 mr-2" />}
                    {node.type === 'container' && <Activity className="w-5 h-5 text-blue-400 mr-2" />}
                    {node.type === 'network' && <Network className="w-5 h-5 text-green-400 mr-2" />}
                    <div>
                        <h2 className="text-white font-semibold">{node.name}</h2>
                        <p className="text-gray-400 text-sm">{node.role}</p>
                    </div>
                </div>
                <button
                    onClick={onClose}
                    className="text-gray-400 hover:text-white transition-colors"
                >
                    <X className="w-5 h-5" />
                </button>
            </div>

            {/* Status Badge */}
            <div className="p-4 border-b border-gray-700">
                <div className="flex items-center justify-between">
                    <span className="text-gray-400">Status</span>
                    <span
                        className={`px-3 py-1 rounded-full text-xs font-semibold ${
                            node.status === 'online'
                                ? 'bg-green-900 text-green-200'
                                : 'bg-red-900 text-red-200'
                        }`}
                    >
                        {node.status}
                    </span>
                </div>
                <div className="flex items-center justify-between mt-2">
                    <span className="text-gray-400">Health Score</span>
                    <div className="flex items-center">
                        <div className="w-32 h-2 bg-gray-700 rounded-full mr-2">
                            <div
                                className="h-full rounded-full transition-all"
                                style={{
                                    width: `${node.health}%`,
                                    backgroundColor:
                                        node.health >= 90
                                            ? '#10B981'
                                            : node.health >= 70
                                            ? '#F59E0B'
                                            : '#EF4444',
                                }}
                            ></div>
                        </div>
                        <span className="text-white font-semibold">{node.health}%</span>
                    </div>
                </div>
            </div>

            {/* IP Addresses */}
            <div className="p-4 border-b border-gray-700">
                <h3 className="text-white font-semibold mb-3">IP Addresses</h3>
                <div className="space-y-2">
                    {node.ips?.wireguard && (
                        <div className="flex items-center justify-between bg-gray-900 p-2 rounded">
                            <span className="text-gray-400 text-sm">WireGuard</span>
                            <code className="text-green-400 text-sm">{node.ips.wireguard}</code>
                        </div>
                    )}
                    {node.ips?.lan && (
                        <div className="flex items-center justify-between bg-gray-900 p-2 rounded">
                            <span className="text-gray-400 text-sm">LAN</span>
                            <code className="text-blue-400 text-sm">{node.ips.lan}</code>
                        </div>
                    )}
                    {node.ips?.tailscale && (
                        <div className="flex items-center justify-between bg-gray-900 p-2 rounded">
                            <span className="text-gray-400 text-sm">Tailscale</span>
                            <code className="text-purple-400 text-sm">{node.ips.tailscale}</code>
                        </div>
                    )}
                </div>
            </div>

            {/* Specifications */}
            {node.specs && (
                <div className="p-4 border-b border-gray-700">
                    <h3 className="text-white font-semibold mb-3">Specifications</h3>
                    <div className="grid grid-cols-2 gap-3">
                        {node.specs.cpu_cores && (
                            <div className="bg-gray-900 p-3 rounded">
                                <div className="text-gray-400 text-xs">CPU Cores</div>
                                <div className="text-white font-semibold">{node.specs.cpu_cores}</div>
                            </div>
                        )}
                        {node.specs.ram_gb && (
                            <div className="bg-gray-900 p-3 rounded">
                                <div className="text-gray-400 text-xs">RAM</div>
                                <div className="text-white font-semibold">{node.specs.ram_gb} GB</div>
                            </div>
                        )}
                        {node.specs.storage_tb && (
                            <div className="bg-gray-900 p-3 rounded">
                                <div className="text-gray-400 text-xs">Storage</div>
                                <div className="text-white font-semibold">{node.specs.storage_tb} TB</div>
                            </div>
                        )}
                        {node.specs.storage_gb && (
                            <div className="bg-gray-900 p-3 rounded">
                                <div className="text-gray-400 text-xs">Storage</div>
                                <div className="text-white font-semibold">{node.specs.storage_gb} GB</div>
                            </div>
                        )}
                    </div>
                </div>
            )}

            {/* Real-Time Metrics */}
            {loading ? (
                <div className="p-4 text-center">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto"></div>
                    <p className="text-gray-400 text-sm mt-2">Loading metrics...</p>
                </div>
            ) : metrics ? (
                <div className="p-4 border-b border-gray-700">
                    <h3 className="text-white font-semibold mb-3">Real-Time Metrics</h3>
                    <div className="space-y-3">
                        <div>
                            <div className="flex items-center justify-between mb-1">
                                <span className="text-gray-400 text-sm">CPU Usage</span>
                                <span className="text-white text-sm font-semibold">
                                    {metrics.cpu_percent}%
                                </span>
                            </div>
                            <div className="w-full h-2 bg-gray-700 rounded-full">
                                <div
                                    className="h-full rounded-full bg-blue-500 transition-all"
                                    style={{ width: `${metrics.cpu_percent}%` }}
                                ></div>
                            </div>
                        </div>
                        <div>
                            <div className="flex items-center justify-between mb-1">
                                <span className="text-gray-400 text-sm">Memory Usage</span>
                                <span className="text-white text-sm font-semibold">
                                    {metrics.ram_percent}%
                                </span>
                            </div>
                            <div className="w-full h-2 bg-gray-700 rounded-full">
                                <div
                                    className="h-full rounded-full bg-purple-500 transition-all"
                                    style={{ width: `${metrics.ram_percent}%` }}
                                ></div>
                            </div>
                        </div>
                        <div>
                            <div className="flex items-center justify-between mb-1">
                                <span className="text-gray-400 text-sm">Network I/O</span>
                                <span className="text-white text-sm font-semibold">
                                    {metrics.network_io_mbps} Mbps
                                </span>
                            </div>
                            <div className="w-full h-2 bg-gray-700 rounded-full">
                                <div
                                    className="h-full rounded-full bg-green-500 transition-all"
                                    style={{
                                        width: `${Math.min((metrics.network_io_mbps / 1000) * 100, 100)}%`,
                                    }}
                                ></div>
                            </div>
                        </div>
                        <div className="bg-gray-900 p-2 rounded">
                            <div className="flex items-center justify-between">
                                <span className="text-gray-400 text-sm">Uptime</span>
                                <span className="text-white text-sm">{metrics.uptime_days} days</span>
                            </div>
                        </div>
                    </div>
                </div>
            ) : null}

            {/* Location */}
            {node.location && (
                <div className="p-4 border-b border-gray-700">
                    <h3 className="text-white font-semibold mb-2">Location</h3>
                    <p className="text-gray-400">{node.location}</p>
                </div>
            )}

            {/* Quick Actions */}
            <div className="p-4">
                <h3 className="text-white font-semibold mb-3">Quick Actions</h3>
                <div className="space-y-2">
                    <button
                        onClick={handleSSH}
                        className="w-full flex items-center justify-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors"
                    >
                        <Terminal className="w-4 h-4 mr-2" />
                        SSH Connect
                    </button>
                    <button
                        onClick={handleMonitor}
                        className="w-full flex items-center justify-center px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded transition-colors"
                    >
                        <Activity className="w-4 h-4 mr-2" />
                        Monitor
                    </button>
                    {node.type !== 'server' && (
                        <button
                            onClick={handleRestart}
                            className="w-full flex items-center justify-center px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white rounded transition-colors"
                        >
                            <HardDrive className="w-4 h-4 mr-2" />
                            Restart
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}
