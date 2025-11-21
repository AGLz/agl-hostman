import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Activity, Server, AlertTriangle, CheckCircle, XCircle, RefreshCw, TrendingUp, TrendingDown } from 'lucide-react';

/**
 * Infrastructure Dashboard Component
 *
 * Real-time monitoring dashboard for Proxmox infrastructure.
 * Features:
 * - Live metrics updates via polling/WebSocket
 * - Container health status indicators
 * - Resource utilization charts
 * - Alert system integration
 * - Responsive grid layout
 *
 * @component
 */
const InfrastructureDashboard = ({ refreshInterval = 30000, enableWebSocket = true }) => {
    const [servers, setServers] = useState([]);
    const [containers, setContainers] = useState([]);
    const [metrics, setMetrics] = useState({});
    const [alerts, setAlerts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [lastUpdate, setLastUpdate] = useState(null);
    const [autoRefresh, setAutoRefresh] = useState(true);

    /**
     * Fetch infrastructure data from API
     */
    const fetchInfrastructureData = useCallback(async () => {
        try {
            const [serversRes, containersRes, metricsRes, alertsRes] = await Promise.all([
                fetch('/api/proxmox/servers'),
                fetch('/api/proxmox/containers'),
                fetch('/api/infrastructure/metrics'),
                fetch('/api/infrastructure/alerts'),
            ]);

            const [serversData, containersData, metricsData, alertsData] = await Promise.all([
                serversRes.json(),
                containersRes.json(),
                metricsRes.json(),
                alertsRes.json(),
            ]);

            setServers(serversData.data || []);
            setContainers(containersData.data || []);
            setMetrics(metricsData.data || {});
            setAlerts(alertsData.data || []);
            setLastUpdate(new Date());
            setLoading(false);
        } catch (error) {
            console.error('Failed to fetch infrastructure data:', error);
            setLoading(false);
        }
    }, []);

    /**
     * Setup WebSocket connection for real-time updates
     */
    useEffect(() => {
        if (!enableWebSocket) return;

        const ws = new WebSocket(
            `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}/ws/infrastructure`
        );

        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);

            switch (data.type) {
                case 'metrics':
                    setMetrics(prev => ({ ...prev, ...data.payload }));
                    break;
                case 'container_update':
                    setContainers(prev =>
                        prev.map(c => c.vmid === data.payload.vmid ? { ...c, ...data.payload } : c)
                    );
                    break;
                case 'alert':
                    setAlerts(prev => [data.payload, ...prev].slice(0, 10));
                    break;
            }
        };

        ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };

        return () => ws.close();
    }, [enableWebSocket]);

    /**
     * Auto-refresh polling
     */
    useEffect(() => {
        if (!autoRefresh) return;

        fetchInfrastructureData();
        const interval = setInterval(fetchInfrastructureData, refreshInterval);

        return () => clearInterval(interval);
    }, [autoRefresh, refreshInterval, fetchInfrastructureData]);

    /**
     * Calculate aggregate statistics
     */
    const stats = useMemo(() => {
        const totalContainers = containers.length;
        const runningContainers = containers.filter(c => c.status === 'running').length;
        const healthyContainers = containers.filter(c => c.is_healthy).length;
        const criticalAlerts = alerts.filter(a => a.severity === 'critical').length;

        const avgCpu = containers.reduce((sum, c) => sum + (c.cpu_usage || 0), 0) / totalContainers || 0;
        const avgMemory = containers.reduce((sum, c) => sum + (c.memory?.percent || 0), 0) / totalContainers || 0;

        return {
            totalContainers,
            runningContainers,
            healthyContainers,
            stoppedContainers: totalContainers - runningContainers,
            criticalAlerts,
            avgCpu: avgCpu.toFixed(1),
            avgMemory: avgMemory.toFixed(1),
            healthRate: totalContainers > 0 ? ((healthyContainers / totalContainers) * 100).toFixed(1) : 0,
        };
    }, [containers, alerts]);

    /**
     * Get status color
     */
    const getStatusColor = (status) => {
        switch (status) {
            case 'running':
            case 'healthy':
                return 'text-green-600 bg-green-50';
            case 'stopped':
                return 'text-gray-600 bg-gray-50';
            case 'warning':
                return 'text-yellow-600 bg-yellow-50';
            case 'critical':
            case 'error':
                return 'text-red-600 bg-red-50';
            default:
                return 'text-gray-600 bg-gray-50';
        }
    };

    /**
     * Get status icon
     */
    const getStatusIcon = (status) => {
        switch (status) {
            case 'running':
            case 'healthy':
                return <CheckCircle className="w-5 h-5" />;
            case 'warning':
                return <AlertTriangle className="w-5 h-5" />;
            case 'critical':
            case 'error':
            case 'stopped':
                return <XCircle className="w-5 h-5" />;
            default:
                return <Activity className="w-5 h-5" />;
        }
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-64">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Infrastructure Dashboard</h1>
                    <p className="text-sm text-gray-500 mt-1">
                        Last updated: {lastUpdate?.toLocaleTimeString()}
                    </p>
                </div>
                <div className="flex items-center gap-3">
                    <button
                        onClick={() => setAutoRefresh(!autoRefresh)}
                        className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                            autoRefresh
                                ? 'bg-blue-100 text-blue-700'
                                : 'bg-gray-100 text-gray-700'
                        }`}
                    >
                        Auto-refresh {autoRefresh ? 'ON' : 'OFF'}
                    </button>
                    <button
                        onClick={fetchInfrastructureData}
                        className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                    >
                        <RefreshCw className="w-4 h-4" />
                        Refresh
                    </button>
                </div>
            </div>

            {/* Statistics Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard
                    title="Total Containers"
                    value={stats.totalContainers}
                    subtitle={`${stats.runningContainers} running`}
                    icon={<Server className="w-6 h-6" />}
                    color="blue"
                />
                <StatCard
                    title="Health Rate"
                    value={`${stats.healthRate}%`}
                    subtitle={`${stats.healthyContainers} healthy`}
                    icon={<CheckCircle className="w-6 h-6" />}
                    color="green"
                    trend={stats.healthRate > 90 ? 'up' : stats.healthRate < 70 ? 'down' : null}
                />
                <StatCard
                    title="Avg CPU Usage"
                    value={`${stats.avgCpu}%`}
                    subtitle="Across all containers"
                    icon={<Activity className="w-6 h-6" />}
                    color="purple"
                    trend={stats.avgCpu < 70 ? 'up' : stats.avgCpu > 85 ? 'down' : null}
                />
                <StatCard
                    title="Critical Alerts"
                    value={stats.criticalAlerts}
                    subtitle={alerts.length > 0 ? `${alerts.length} total` : 'All clear'}
                    icon={<AlertTriangle className="w-6 h-6" />}
                    color="red"
                />
            </div>

            {/* Servers Grid */}
            <div className="bg-white rounded-lg shadow-sm border border-gray-200">
                <div className="px-6 py-4 border-b border-gray-200">
                    <h2 className="text-lg font-semibold text-gray-900">Proxmox Servers</h2>
                </div>
                <div className="divide-y divide-gray-200">
                    {servers.map((server) => (
                        <ServerCard key={server.id} server={server} />
                    ))}
                </div>
            </div>

            {/* Containers Grid */}
            <div className="bg-white rounded-lg shadow-sm border border-gray-200">
                <div className="px-6 py-4 border-b border-gray-200">
                    <h2 className="text-lg font-semibold text-gray-900">Containers</h2>
                </div>
                <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                        <thead className="bg-gray-50">
                            <tr>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Name
                                </th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Status
                                </th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    CPU
                                </th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Memory
                                </th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Disk
                                </th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                    Uptime
                                </th>
                            </tr>
                        </thead>
                        <tbody className="bg-white divide-y divide-gray-200">
                            {containers.map((container) => (
                                <tr key={container.vmid} className="hover:bg-gray-50">
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        <div className="flex items-center">
                                            <div className="text-sm font-medium text-gray-900">
                                                {container.name}
                                            </div>
                                            <span className="ml-2 text-xs text-gray-500">
                                                CT{container.vmid}
                                            </span>
                                        </div>
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(container.health_status)}`}>
                                            {getStatusIcon(container.health_status)}
                                            {container.status}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        <div className="text-sm text-gray-900">
                                            {container.cpu_usage?.toFixed(1)}%
                                        </div>
                                        <ProgressBar value={container.cpu_usage} max={100} color="blue" />
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        <div className="text-sm text-gray-900">
                                            {container.memory?.percent?.toFixed(1)}%
                                        </div>
                                        <ProgressBar value={container.memory?.percent} max={100} color="purple" />
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        <div className="text-sm text-gray-900">
                                            {container.disk?.percent?.toFixed(1)}%
                                        </div>
                                        <ProgressBar value={container.disk?.percent} max={100} color="green" />
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                        {container.uptime_formatted || 'N/A'}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Recent Alerts */}
            {alerts.length > 0 && (
                <div className="bg-white rounded-lg shadow-sm border border-gray-200">
                    <div className="px-6 py-4 border-b border-gray-200">
                        <h2 className="text-lg font-semibold text-gray-900">Recent Alerts</h2>
                    </div>
                    <div className="divide-y divide-gray-200">
                        {alerts.slice(0, 5).map((alert, index) => (
                            <AlertItem key={index} alert={alert} />
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
};

/**
 * Stat Card Component
 */
const StatCard = ({ title, value, subtitle, icon, color, trend }) => {
    const colorClasses = {
        blue: 'bg-blue-50 text-blue-600',
        green: 'bg-green-50 text-green-600',
        purple: 'bg-purple-50 text-purple-600',
        red: 'bg-red-50 text-red-600',
    };

    return (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
                <div className={`p-3 rounded-lg ${colorClasses[color]}`}>
                    {icon}
                </div>
                {trend && (
                    <div className={`flex items-center gap-1 text-sm ${trend === 'up' ? 'text-green-600' : 'text-red-600'}`}>
                        {trend === 'up' ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
                    </div>
                )}
            </div>
            <div>
                <p className="text-sm text-gray-500 mb-1">{title}</p>
                <p className="text-3xl font-bold text-gray-900 mb-1">{value}</p>
                <p className="text-sm text-gray-500">{subtitle}</p>
            </div>
        </div>
    );
};

/**
 * Server Card Component
 */
const ServerCard = ({ server }) => {
    return (
        <div className="px-6 py-4 hover:bg-gray-50">
            <div className="flex items-center justify-between">
                <div>
                    <h3 className="text-sm font-medium text-gray-900">{server.name}</h3>
                    <p className="text-sm text-gray-500">{server.ip_address}</p>
                </div>
                <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium ${
                    server.status === 'online' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'
                }`}>
                    {server.status}
                </span>
            </div>
        </div>
    );
};

/**
 * Progress Bar Component
 */
const ProgressBar = ({ value, max, color }) => {
    const percentage = (value / max) * 100;
    const colorClasses = {
        blue: 'bg-blue-600',
        purple: 'bg-purple-600',
        green: 'bg-green-600',
    };

    return (
        <div className="w-full bg-gray-200 rounded-full h-1.5 mt-1">
            <div
                className={`h-1.5 rounded-full transition-all duration-300 ${colorClasses[color]}`}
                style={{ width: `${Math.min(percentage, 100)}%` }}
            />
        </div>
    );
};

/**
 * Alert Item Component
 */
const AlertItem = ({ alert }) => {
    const severityColors = {
        critical: 'text-red-600 bg-red-50',
        high: 'text-orange-600 bg-orange-50',
        medium: 'text-yellow-600 bg-yellow-50',
        low: 'text-blue-600 bg-blue-50',
    };

    return (
        <div className="px-6 py-4 hover:bg-gray-50">
            <div className="flex items-start justify-between">
                <div className="flex items-start gap-3">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${severityColors[alert.severity]}`}>
                        {alert.severity}
                    </span>
                    <div>
                        <p className="text-sm font-medium text-gray-900">{alert.title}</p>
                        <p className="text-sm text-gray-500 mt-1">{alert.message}</p>
                        {alert.server && (
                            <p className="text-xs text-gray-400 mt-1">Server: {alert.server}</p>
                        )}
                    </div>
                </div>
                <span className="text-xs text-gray-400">
                    {new Date(alert.timestamp).toLocaleTimeString()}
                </span>
            </div>
        </div>
    );
};

export default InfrastructureDashboard;
