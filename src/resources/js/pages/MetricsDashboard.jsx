import React, { useState, useEffect, useRef } from 'react';
import { Line, Bar, Scatter, Bubble } from 'react-chartjs-2';
import {
    Chart as ChartJS,
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    BarElement,
    Title,
    Tooltip,
    Legend,
    Filler,
    TimeScale
} from 'chart.js';
import 'chartjs-adapter-date-fns';
import { format } from 'date-fns';
// import Echo from 'laravel-echo'; // Disabled - no Reverb configured
// import Pusher from 'pusher-js'; // Disabled - no Reverb configured
import { 
    Activity,
    Cpu,
    HardDrive,
    MemoryStick,
    Network,
    Server,
    Zap,
    TrendingUp,
    TrendingDown,
    AlertCircle,
    CheckCircle,
    Clock,
    RefreshCw,
    Settings,
    Download
} from 'lucide-react';
import { Button } from '@/components/ui/button';

ChartJS.register(
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    BarElement,
    Title,
    Tooltip,
    Legend,
    Filler,
    TimeScale
);

// window.Pusher = Pusher; // Disabled

function MetricsDashboard() {
    const [metrics, setMetrics] = useState({
        cpu: [],
        memory: [],
        disk: [],
        network: [],
        containers: [],
        services: []
    });
    
    const [realTimeMetrics, setRealTimeMetrics] = useState([]);
    const [selectedMetric, setSelectedMetric] = useState('cpu');
    const [timeRange, setTimeRange] = useState('1h');
    const [autoUpdate, setAutoUpdate] = useState(true);
    const [serverStats, setServerStats] = useState({});
    const chartRef = useRef(null);
    const echoRef = useRef(null);
    
    const MAX_DATA_POINTS = 100;

    useEffect(() => {
        // Echo/WebSocket disabled - no Reverb configured
        // Initial data fetch
        fetchMetricsData();

        // Auto update interval
        const interval = autoUpdate ? setInterval(() => {
            fetchMetricsData();
        }, 5000) : null;

        return () => {
            if (interval) clearInterval(interval);
        };
    }, [timeRange, autoUpdate]);

    const fetchMetricsData = async () => {
        try {
            const response = await fetch(`/api/metrics/realtime?range=${timeRange}`, {
                headers: {
                    'Accept': 'application/json',
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                processMetricsData(data);
            }
        } catch (error) {
            console.error('Failed to fetch metrics:', error);
        }
    };

    const processMetricsData = (data) => {
        const processed = {
            cpu: [],
            memory: [],
            disk: [],
            network: [],
            containers: [],
            services: []
        };

        // Process time series data
        if (data.timeseries) {
            data.timeseries.forEach(point => {
                const timestamp = new Date(point.timestamp);
                
                processed.cpu.push({
                    x: timestamp,
                    y: point.cpu || 0
                });
                
                processed.memory.push({
                    x: timestamp,
                    y: point.memory || 0
                });
                
                processed.disk.push({
                    x: timestamp,
                    y: point.disk || 0
                });
                
                processed.network.push({
                    x: timestamp,
                    y: point.network || 0
                });
            });
        }

        // Process server stats
        if (data.servers) {
            setServerStats(data.servers);
        }

        setMetrics(processed);
    };

    const handleMetricUpdate = (data) => {
        const timestamp = new Date(data.timestamp);
        
        setMetrics(prev => {
            const updated = { ...prev };
            
            // Add new data point
            if (data.metric === 'cpu' && updated.cpu) {
                updated.cpu.push({ x: timestamp, y: data.value });
                if (updated.cpu.length > MAX_DATA_POINTS) {
                    updated.cpu.shift();
                }
            }
            
            if (data.metric === 'memory' && updated.memory) {
                updated.memory.push({ x: timestamp, y: data.value });
                if (updated.memory.length > MAX_DATA_POINTS) {
                    updated.memory.shift();
                }
            }
            
            if (data.metric === 'network' && updated.network) {
                updated.network.push({ x: timestamp, y: data.value });
                if (updated.network.length > MAX_DATA_POINTS) {
                    updated.network.shift();
                }
            }
            
            return updated;
        });

        // Add to real-time feed
        setRealTimeMetrics(prev => {
            const updated = [data, ...prev].slice(0, 20);
            return updated;
        });
    };

    const handleAlert = (alert) => {
        // Show notification
        console.log('Alert received:', alert);
        
        // Add to real-time feed
        setRealTimeMetrics(prev => {
            const alertItem = {
                ...alert,
                type: 'alert',
                timestamp: new Date().toISOString()
            };
            return [alertItem, ...prev].slice(0, 20);
        });
    };

    const exportData = () => {
        const dataStr = JSON.stringify(metrics, null, 2);
        const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
        
        const exportFileDefaultName = `metrics_${format(new Date(), 'yyyy-MM-dd_HH-mm-ss')}.json`;
        
        const linkElement = document.createElement('a');
        linkElement.setAttribute('href', dataUri);
        linkElement.setAttribute('download', exportFileDefaultName);
        linkElement.click();
    };

    // Chart configurations
    const getChartData = () => {
        const dataset = metrics[selectedMetric] || [];
        
        return {
            datasets: [{
                label: selectedMetric.toUpperCase(),
                data: dataset,
                borderColor: getMetricColor(selectedMetric),
                backgroundColor: getMetricColor(selectedMetric, 0.1),
                tension: 0.4,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 4,
            }]
        };
    };

    const getMetricColor = (metric, alpha = 1) => {
        const colors = {
            cpu: `rgba(59, 130, 246, ${alpha})`,
            memory: `rgba(147, 51, 234, ${alpha})`,
            disk: `rgba(34, 197, 94, ${alpha})`,
            network: `rgba(251, 146, 60, ${alpha})`,
        };
        return colors[metric] || `rgba(107, 114, 128, ${alpha})`;
    };

    const chartOptions = {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
            mode: 'index',
            intersect: false,
        },
        plugins: {
            legend: {
                display: false,
            },
            tooltip: {
                callbacks: {
                    title: (context) => {
                        if (context[0].parsed.x) {
                            return format(new Date(context[0].parsed.x), 'HH:mm:ss');
                        }
                        return '';
                    },
                    label: (context) => {
                        return `${context.dataset.label}: ${context.parsed.y.toFixed(2)}%`;
                    }
                }
            }
        },
        scales: {
            x: {
                type: 'time',
                time: {
                    unit: 'minute',
                    displayFormats: {
                        minute: 'HH:mm'
                    }
                },
                grid: {
                    display: false
                }
            },
            y: {
                beginAtZero: true,
                max: 100,
                ticks: {
                    callback: (value) => `${value}%`
                }
            }
        }
    };

    const getServerStatus = (status) => {
        if (status === 'healthy') return { icon: CheckCircle, color: 'text-green-500' };
        if (status === 'warning') return { icon: AlertCircle, color: 'text-yellow-500' };
        return { icon: AlertCircle, color: 'text-red-500' };
    };

    return (
        <div className="min-h-screen bg-gray-50 p-6">
            {/* Header */}
            <div className="mb-8">
                <h1 className="text-3xl font-bold text-gray-900 mb-2">Real-Time Metrics Dashboard</h1>
                <div className="flex items-center justify-between">
                    <p className="text-gray-500">Live infrastructure performance monitoring</p>
                    <div className="flex items-center gap-4">
                        <select
                            value={timeRange}
                            onChange={(e) => setTimeRange(e.target.value)}
                            className="px-3 py-2 border border-gray-300 rounded-md"
                        >
                            <option value="5m">Last 5 minutes</option>
                            <option value="15m">Last 15 minutes</option>
                            <option value="1h">Last hour</option>
                            <option value="6h">Last 6 hours</option>
                            <option value="24h">Last 24 hours</option>
                        </select>
                        
                        <Button
                            variant={autoUpdate ? "default" : "outline"}
                            onClick={() => setAutoUpdate(!autoUpdate)}
                            className="flex items-center gap-2"
                        >
                            <RefreshCw className={`h-4 w-4 ${autoUpdate ? 'animate-spin' : ''}`} />
                            {autoUpdate ? 'Live' : 'Paused'}
                        </Button>
                        
                        <Button onClick={exportData} variant="outline">
                            <Download className="h-4 w-4 mr-2" />
                            Export
                        </Button>
                    </div>
                </div>
            </div>

            {/* Metric Selector */}
            <div className="grid grid-cols-4 gap-4 mb-8">
                {[
                    { key: 'cpu', icon: Cpu, label: 'CPU Usage' },
                    { key: 'memory', icon: MemoryStick, label: 'Memory' },
                    { key: 'disk', icon: HardDrive, label: 'Disk I/O' },
                    { key: 'network', icon: Network, label: 'Network' }
                ].map((metric) => (
                    <button
                        key={metric.key}
                        onClick={() => setSelectedMetric(metric.key)}
                        className={`p-4 rounded-lg border-2 transition-all ${
                            selectedMetric === metric.key
                                ? 'border-blue-500 bg-blue-50'
                                : 'border-gray-200 bg-white hover:border-gray-300'
                        }`}
                    >
                        <div className="flex items-center justify-between mb-2">
                            <metric.icon className={`h-5 w-5 ${
                                selectedMetric === metric.key ? 'text-blue-600' : 'text-gray-500'
                            }`} />
                            <span className="text-2xl font-bold">
                                {metrics[metric.key]?.slice(-1)[0]?.y?.toFixed(1) || '0'}%
                            </span>
                        </div>
                        <p className={`text-sm ${
                            selectedMetric === metric.key ? 'text-blue-700' : 'text-gray-600'
                        }`}>
                            {metric.label}
                        </p>
                    </button>
                ))}
            </div>

            {/* Main Chart */}
            <div className="bg-white rounded-lg p-6 shadow-sm mb-8">
                <h2 className="text-lg font-semibold mb-4 capitalize">{selectedMetric} Performance</h2>
                <div className="h-80">
                    <Line ref={chartRef} data={getChartData()} options={chartOptions} />
                </div>
            </div>

            {/* Server Status Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
                {/* Server Status */}
                <div className="bg-white rounded-lg p-6 shadow-sm">
                    <h3 className="text-lg font-semibold mb-4">Server Status</h3>
                    <div className="space-y-3">
                        {Object.entries(serverStats).map(([server, stats]) => {
                            const StatusIcon = getServerStatus(stats.status).icon;
                            const statusColor = getServerStatus(stats.status).color;
                            
                            return (
                                <div key={server} className="flex items-center justify-between p-3 bg-gray-50 rounded">
                                    <div className="flex items-center gap-3">
                                        <Server className="h-5 w-5 text-gray-600" />
                                        <div>
                                            <p className="font-medium">{server}</p>
                                            <p className="text-xs text-gray-500">{stats.ip}</p>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-4">
                                        <div className="text-right">
                                            <p className="text-sm">CPU: {stats.cpu}%</p>
                                            <p className="text-sm">MEM: {stats.memory}%</p>
                                        </div>
                                        <StatusIcon className={`h-5 w-5 ${statusColor}`} />
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                </div>

                {/* Real-Time Feed */}
                <div className="bg-white rounded-lg p-6 shadow-sm">
                    <h3 className="text-lg font-semibold mb-4">Real-Time Activity</h3>
                    <div className="space-y-2 max-h-96 overflow-y-auto">
                        {realTimeMetrics.map((item, index) => (
                            <div key={index} className="flex items-start gap-3 p-2 hover:bg-gray-50 rounded">
                                <div className="mt-1">
                                    {item.type === 'alert' ? (
                                        <AlertCircle className="h-4 w-4 text-red-500" />
                                    ) : (
                                        <Activity className="h-4 w-4 text-blue-500" />
                                    )}
                                </div>
                                <div className="flex-1">
                                    <p className="text-sm">
                                        {item.type === 'alert' ? (
                                            <span className="font-medium text-red-600">{item.message}</span>
                                        ) : (
                                            <>
                                                <span className="font-medium">{item.metric}</span>
                                                <span className="ml-2">{item.value?.toFixed(2)}%</span>
                                            </>
                                        )}
                                    </p>
                                    <p className="text-xs text-gray-500">
                                        {format(new Date(item.timestamp), 'HH:mm:ss')}
                                        {item.server && ` • ${item.server}`}
                                    </p>
                                </div>
                            </div>
                        ))}
                        
                        {realTimeMetrics.length === 0 && (
                            <p className="text-center text-gray-500 py-8">
                                Waiting for real-time updates...
                            </p>
                        )}
                    </div>
                </div>
            </div>

            {/* Performance Indicators */}
            <div className="grid grid-cols-4 gap-4">
                <div className="bg-white rounded-lg p-4 shadow-sm">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-sm text-gray-500">Avg Response Time</span>
                        <Clock className="h-4 w-4 text-gray-400" />
                    </div>
                    <p className="text-2xl font-bold">142ms</p>
                    <p className="text-xs text-green-600 flex items-center gap-1 mt-1">
                        <TrendingDown className="h-3 w-3" />
                        -12% from last hour
                    </p>
                </div>

                <div className="bg-white rounded-lg p-4 shadow-sm">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-sm text-gray-500">Requests/sec</span>
                        <Zap className="h-4 w-4 text-gray-400" />
                    </div>
                    <p className="text-2xl font-bold">3,847</p>
                    <p className="text-xs text-green-600 flex items-center gap-1 mt-1">
                        <TrendingUp className="h-3 w-3" />
                        +8% from last hour
                    </p>
                </div>

                <div className="bg-white rounded-lg p-4 shadow-sm">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-sm text-gray-500">Error Rate</span>
                        <AlertCircle className="h-4 w-4 text-gray-400" />
                    </div>
                    <p className="text-2xl font-bold">0.12%</p>
                    <p className="text-xs text-gray-600 flex items-center gap-1 mt-1">
                        <TrendingUp className="h-3 w-3" />
                        Stable
                    </p>
                </div>

                <div className="bg-white rounded-lg p-4 shadow-sm">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-sm text-gray-500">Uptime</span>
                        <CheckCircle className="h-4 w-4 text-gray-400" />
                    </div>
                    <p className="text-2xl font-bold">99.98%</p>
                    <p className="text-xs text-gray-600 mt-1">
                        30 days
                    </p>
                </div>
            </div>
        </div>
    );
}

export default MetricsDashboard;