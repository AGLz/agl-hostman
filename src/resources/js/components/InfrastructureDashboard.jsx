import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Activity, Server, AlertTriangle, CheckCircle, XCircle, RefreshCw, Clock } from 'lucide-react';
import { useWebSocket } from '../hooks/useWebSocket';
import { useSystemMonitoring } from '../hooks/useWebSocket';
import { useContainerStatus } from '../hooks/useWebSocket';
import ConnectionStatus from './ConnectionStatus';
import NotificationBadge from './NotificationBadge';

/**
 * Infrastructure Dashboard Component with Real-time Updates
 *
 * Real-time monitoring dashboard for Proxmox infrastructure.
 * Features:
 * - Live metrics updates via WebSocket
 * - Container health status indicators
 * - Resource utilization charts
 * - Alert system integration
 * - Animated status badges
 * - Loading skeletons
 * - Connection status indicator
 * - Notification badges
 *
 * @component
 */
const InfrastructureDashboard = ({ refreshInterval = 30000, enableWebSocket = true }) => {
    // UI state
    const [servers, setServers] = useState([]);
    const [containers, setContainers] = useState([]);
    const [metrics, setMetrics] = useState({});
    const [alerts, setAlerts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [initialLoad, setInitialLoad] = useState(true);
    const [lastUpdate, setLastUpdate] = useState(null);
    const [autoRefresh, setAutoRefresh] = useState(true);

    // WebSocket connection status
    const { isConnected, connectionState } = useWebSocket({
        enableReconnect: true,
        reconnectInterval: 1000,
        maxReconnectInterval: 30000,
        maxReconnectAttempts: 10,
    });

    // Real-time system metrics
    const { metrics: systemMetrics } = useSystemMonitoring((data) => {
        console.log('[Dashboard] System metrics updated:', data);
        setMetrics(data);
        setLastUpdate(new Date());
    });

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
            setInitialLoad(false);
        } catch (error) {
            console.error('Failed to fetch infrastructure data:', error);
            setLoading(false);
            setInitialLoad(false);
        }
    }, []);

    /**
     * Subscribe to individual container status updates
     */
    const subscribeToContainers = useCallback(() => {
        if (!enableWebSocket || !containers.length) return;

        containers.forEach(container => {
            useContainerStatus(container.vmid, (data) => {
                console.log(`[Dashboard] Container ${container.vmid} status:`, data);
                setContainers(prev =>
                    prev.map(c => c.vmid === data.vmid ? { ...c, ...data } : c)
                );
                setLastUpdate(new Date());
            });
        });
    }, [containers, enableWebSocket]);

    /**
     * Initial data fetch
     */
    useEffect(() => {
        fetchInfrastructureData();
    }, [fetchInfrastructureData]);

    /**
     * Subscribe to container updates when containers change
     */
    useEffect(() => {
        if (enableWebSocket && !initialLoad) {
            subscribeToContainers();
        }
    }, [containers, enableWebSocket, initialLoad, subscribeToContainers]);

    /**
     * Auto-refresh polling (fallback when WebSocket unavailable)
     */
    useEffect(() => {
        if (!autoRefresh || isConnected) return; // Don't poll if WebSocket is connected

        const interval = setInterval(fetchInfrastructureData, refreshInterval);
        return () => clearInterval(interval);
    }, [autoRefresh, isConnected, refreshInterval, fetchInfrastructureData]);

    /**
     * Manual refresh handler
     */
    const handleRefresh = useCallback(() => {
        setLoading(true);
        fetchInfrastructureData();
    }, [fetchInfrastructureData]);

    /**
     * Memoized metrics for performance
     */
    const overallHealth = useMemo(() => {
        if (!servers.length) return null;

        const onlineServers = servers.filter(s => s.status === 'online').length;
        const healthScore = (onlineServers / servers.length) * 100;

        return {
            score: healthScore,
            status: healthScore >= 80 ? 'healthy' : healthScore >= 50 ? 'degraded' : 'critical',
            onlineServers,
            totalServers: servers.length
        };
    }, [servers]);

    const containerStats = useMemo(() => {
        return {
            total: containers.length,
            running: containers.filter(c => c.status === 'running').length,
            stopped: containers.filter(c => c.status === 'stopped').length,
            error: containers.filter(c => c.status === 'error' || !c.status).length,
        };
    }, [containers]);

    /**
     * Render loading skeleton
     */
    if (initialLoad) {
        return (
            <div className="space-y-6">
                {/* Header skeleton */}
                <div className="animate-pulse bg-white rounded-lg shadow p-6">
                    <div className="h-8 bg-gray-200 rounded w-1/4 mb-4"></div>
                    <div className="space-y-3">
                        <div className="h-4 bg-gray-200 rounded w-3/4"></div>
                        <div className="h-4 bg-gray-200 rounded w-1/2"></div>
                    </div>
                </div>

                {/* Cards skeleton */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    {[1, 2, 3].map(i => (
                        <div key={i} className="animate-pulse bg-white rounded-lg shadow p-6">
                            <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
                            <div className="space-y-2">
                                <div className="h-3 bg-gray-200 rounded"></div>
                                <div className="h-3 bg-gray-200 rounded w-2/3"></div>
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            {/* Header with status indicators */}
            <div className="bg-white rounded-lg shadow p-6">
                <div className="flex items-center justify-between mb-4">
                    <div>
                        <h1 className="text-2xl font-bold text-gray-900">Infrastructure Dashboard</h1>
                        <div className="flex items-center space-x-3 mt-1">
                            {/* Connection status */}
                            <div className="flex items-center space-x-1 text-sm text-gray-600">
                                <ConnectionStatusMini />
                            </div>

                            {/* Last updated timestamp */}
                            {lastUpdate && (
                                <div className="flex items-center space-x-1 text-sm text-gray-500">
                                    <Clock className="w-4 h-4" />
                                    <span>Last updated: {lastUpdate.toLocaleTimeString()}</span>
                                </div>
                            )}
                        </div>
                    </div>

                    <div className="flex items-center space-x-2">
                        {/* Auto-refresh toggle */}
                        <button
                            onClick={() => setAutoRefresh(!autoRefresh)}
                            className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                                autoRefresh
                                    ? 'bg-blue-100 text-blue-700 hover:bg-blue-200'
                                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                            }`}
                        >
                            Auto-refresh: {autoRefresh ? 'On' : 'Off'}
                        </button>

                        {/* Manual refresh button */}
                        <button
                            onClick={handleRefresh}
                            disabled={loading}
                            className="p-2 text-gray-600 hover:text-gray-900 transition-colors disabled:opacity-50"
                            title="Refresh"
                        >
                            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} />
                        </button>

                        {/* Notification badge */}
                        <NotificationBadge />
                    </div>
                </div>

                {/* Health score */}
                {overallHealth && (
                    <div className="flex items-center space-x-4">
                        <div className={`flex items-center space-x-2 px-4 py-2 rounded-lg ${
                            overallHealth.status === 'healthy'
                                ? 'bg-green-50 border border-green-200'
                                : overallHealth.status === 'degraded'
                                ? 'bg-yellow-50 border border-yellow-200'
                                : 'bg-red-50 border border-red-200'
                        }`}>
                            {overallHealth.status === 'healthy' && (
                                <CheckCircle className="w-5 h-5 text-green-600" />
                            )}
                            {overallHealth.status === 'degraded' && (
                                <AlertTriangle className="w-5 h-5 text-yellow-600" />
                            )}
                            {overallHealth.status === 'critical' && (
                                <XCircle className="w-5 h-5 text-red-600" />
                            )}
                            <div>
                                <div className="text-sm font-medium text-gray-900">
                                    Health Score: {overallHealth.score.toFixed(1)}%
                                </div>
                                <div className="text-xs text-gray-600">
                                    {overallHealth.onlineServers}/{overallHealth.totalServers} servers online
                                </div>
                            </div>
                        </div>
                    </div>
                )}
            </div>

            {/* Statistics cards */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                {/* Containers card */}
                <div className="bg-white rounded-lg shadow p-6">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-gray-600">Containers</p>
                            <p className="text-2xl font-bold text-gray-900 mt-1">
                                {containerStats.total}
                            </p>
                            <div className="flex items-center space-x-3 mt-2 text-xs">
                                <span className="text-green-600">
                                    ✓ {containerStats.running} running
                                </span>
                                <span className="text-red-600">
                                    ✗ {containerStats.error} errors
                                </span>
                            </div>
                        </div>
                        <div className="p-3 bg-blue-50 rounded-lg">
                            <Server className="w-6 h-6 text-blue-600" />
                        </div>
                    </div>
                </div>

                {/* Alerts card */}
                <div className="bg-white rounded-lg shadow p-6">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-gray-600">Active Alerts</p>
                            <p className="text-2xl font-bold text-gray-900 mt-1">
                                {alerts.length}
                            </p>
                        </div>
                        <div className={`p-3 rounded-lg ${
                            alerts.length > 0 ? 'bg-red-50' : 'bg-green-50'
                        }`}>
                            <AlertTriangle className={`w-6 h-6 ${
                                alerts.length > 0 ? 'text-red-600' : 'text-green-600'
                            }`} />
                        </div>
                    </div>
                </div>

                {/* CPU usage card */}
                <div className="bg-white rounded-lg shadow p-6">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-gray-600">Avg CPU Usage</p>
                            <p className="text-2xl font-bold text-gray-900 mt-1">
                                {metrics.average_cpu ? `${metrics.average_cpu_usage.toFixed(1)}%` : 'N/A'}
                            </p>
                        </div>
                        <div className="p-3 bg-purple-50 rounded-lg">
                            <Activity className="w-6 h-6 text-purple-600" />
                        </div>
                    </div>
                </div>

                {/* Memory usage card */}
                <div className="bg-white rounded-lg shadow p-6">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-gray-600">Avg Memory Usage</p>
                            <p className="text-2xl font-bold text-gray-900 mt-1">
                                {metrics.average_memory ? `${metrics.average_memory_usage.toFixed(1)}%` : 'N/A'}
                            </p>
                        </div>
                        <div className="p-3 bg-yellow-50 rounded-lg">
                            <TrendingUp className="w-6 h-6 text-yellow-600" />
                        </div>
                    </div>
                </div>
            </div>

            {/* Containers list with real-time status */}
            <div className="bg-white rounded-lg shadow">
                <div className="px-6 py-4 border-b border-gray-200">
                    <h2 className="text-lg font-semibold text-gray-900">Containers</h2>
                </div>
                <div className="p-6">
                    {containers.length === 0 ? (
                        <div className="text-center py-12 text-gray-500">
                            No containers found
                        </div>
                    ) : (
                        <div className="space-y-4">
                            {containers.map((container) => (
                                <ContainerCard
                                    key={container.vmid}
                                    container={container}
                                    enableRealTime={enableWebSocket}
                                />
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* Alerts list */}
            {alerts.length > 0 && (
                <div className="bg-white rounded-lg shadow">
                    <div className="px-6 py-4 border-b border-gray-200">
                        <h2 className="text-lg font-semibold text-gray-900">Recent Alerts</h2>
                    </div>
                    <div className="p-6">
                        <div className="space-y-3">
                            {alerts.slice(0, 5).map((alert, index) => (
                                <AlertItem key={`${alert.resource_id}-${index}`} alert={alert} />
                            ))}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

/**
 * Container Card Component with Real-time Status
 *
 * Displays individual container information with animated status badges
 */
const ContainerCard = React.memo(({ container, enableRealTime = true }) => {
    const [status, setStatus] = useState(container.status);
    const { lastUpdate, error } = useContainerStatus(
        container.vmid,
        (data) => {
            console.log(`[ContainerCard] Update for ${container.vmid}:`, data);
            setStatus(data.status);
        }
    );

    // Update status from WebSocket
    useEffect(() => {
        if (lastUpdate) {
            setStatus(lastUpdate.status);
        }
    }, [lastUpdate]);

    const getStatusColor = () => {
        switch (status) {
            case 'running':
                return 'bg-green-100 text-green-800 border-green-200';
            case 'stopped':
                return 'bg-gray-100 text-gray-800 border-gray-200';
            case 'error':
                return 'bg-red-100 text-red-800 border-red-200';
            default:
                return 'bg-yellow-100 text-yellow-800 border-yellow-200';
        }
    };

    const getStatusIcon = () => {
        switch (status) {
            case 'running':
                return <CheckCircle className="w-4 h-4" />;
            case 'stopped':
                return <XCircle className="w-4 h-4" />;
            case 'error':
                return <AlertTriangle className="w-4 h-4" />;
            default:
                return <Clock className="w-4 h-4" />;
        }
    };

    return (
        <div className="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:shadow-md transition-shadow">
            <div className="flex items-center space-x-4">
                {/* Status badge with animation */}
                <div className={`flex items-center space-x-2 px-3 py-1 rounded-full text-sm font-medium transition-all duration-300 ${getStatusColor()}`}>
                    <div className={lastUpdate ? 'animate-pulse' : ''}>
                        {getStatusIcon()}
                    </div>
                    <span className="capitalize">{status || 'Unknown'}</span>
                </div>

                {/* Container info */}
                <div>
                    <h3 className="font-medium text-gray-900">{container.name || `Container ${container.vmid}`}</h3>
                    <p className="text-sm text-gray-600">
                        VMID: {container.vmid} • Node: {container.node || 'Unknown'}
                    </p>
                </div>
            </div>

            {/* Resource usage */}
            <div className="flex items-center space-x-4 text-sm">
                {container.cpu !== undefined && (
                    <div className="text-center">
                        <p className="text-gray-600">CPU</p>
                        <p className="font-medium text-gray-900">{container.cpu}%</p>
                    </div>
                )}
                {container.memory && (
                    <div className="text-center">
                        <p className="text-gray-600">Memory</p>
                        <p className="font-medium text-gray-900">
                            {typeof container.memory === 'object'
                                ? `${container.memory.used_mb}MB`
                                : container.memory}
                        </p>
                    </div>
                )}
            </div>

            {/* Last update indicator */}
            {lastUpdate && enableRealTime && (
                <div className="text-xs text-gray-500">
                    <span className="inline-block w-2 h-2 bg-green-500 rounded-full animate-pulse mr-1"></span>
                    Live
                </div>
            )}
        </div>
    );
});

/**
 * Alert Item Component
 */
const AlertItem = React.memo(({ alert }) => {
    const getSeverityColor = () => {
        switch (alert.severity) {
            case 'critical':
                return 'bg-red-50 border-red-200 text-red-800';
            case 'warning':
                return 'bg-yellow-50 border-yellow-200 text-yellow-800';
            case 'info':
                return 'bg-blue-50 border-blue-200 text-blue-800';
            default:
                return 'bg-gray-50 border-gray-200 text-gray-800';
        }
    };

    return (
        <div className={`p-4 border rounded-lg ${getSeverityColor()}`}>
            <div className="flex items-start space-x-3">
                <AlertTriangle className="w-5 h-5 flex-shrink-0 mt-0.5" />
                <div className="flex-1">
                    <p className="font-medium">{alert.title}</p>
                    <p className="text-sm mt-1">{alert.message}</p>
                    {alert.resource_id && (
                        <p className="text-xs mt-2 opacity-75">
                            Resource: {alert.resource_type}/{alert.resource_id}
                        </p>
                    )}
                </div>
            </div>
        </div>
    );
});

ContainerCard.displayName = 'ContainerCard';
AlertItem.displayName = 'AlertItem';

export default InfrastructureDashboard;
