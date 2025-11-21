import React, { useState, useEffect } from 'react';
import { Line, Bar, Doughnut, Radar } from 'react-chartjs-2';
import {
    Chart as ChartJS,
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    BarElement,
    ArcElement,
    RadialLinearScale,
    Title,
    Tooltip,
    Legend,
    Filler
} from 'chart.js';
import { format } from 'date-fns';
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';
import { 
    AlertCircle, 
    CheckCircle, 
    Server, 
    Cpu, 
    HardDrive, 
    Activity,
    TrendingUp,
    TrendingDown,
    AlertTriangle,
    Zap,
    Database,
    Network,
    Shield,
    RefreshCw
} from 'lucide-react';
import { Button } from '@/components/ui/button';

// Register Chart.js components
ChartJS.register(
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    BarElement,
    ArcElement,
    RadialLinearScale,
    Title,
    Tooltip,
    Legend,
    Filler
);

window.Pusher = Pusher;

function InfrastructureDashboard() {
    const [metrics, setMetrics] = useState({});
    const [analysis, setAnalysis] = useState(null);
    const [realTimeData, setRealTimeData] = useState([]);
    const [selectedServer, setSelectedServer] = useState(null);
    const [loading, setLoading] = useState(true);
    const [autoRefresh, setAutoRefresh] = useState(true);

    useEffect(() => {
        // Initialize Echo for real-time updates
        const echo = new Echo({
            broadcaster: 'pusher',
            key: process.env.MIX_PUSHER_APP_KEY,
            cluster: process.env.MIX_PUSHER_APP_CLUSTER,
            forceTLS: true,
            authEndpoint: '/broadcasting/auth'
        });

        // Subscribe to infrastructure channel
        echo.private('infrastructure')
            .listen('.status.updated', (e) => {
                handleRealTimeUpdate(e);
            });

        // Initial data fetch
        fetchInfrastructureData();
        fetchAnalytics();

        // Auto refresh
        const interval = autoRefresh ? setInterval(() => {
            fetchInfrastructureData();
            fetchAnalytics();
        }, 30000) : null;

        return () => {
            if (interval) clearInterval(interval);
            echo.disconnect();
        };
    }, [autoRefresh]);

    const fetchInfrastructureData = async () => {
        try {
            const response = await fetch('/api/infrastructure/status', {
                headers: {
                    'Accept': 'application/json',
                }
            });
            if (response.ok) {
                const data = await response.json();
                setMetrics(data);
            }
        } catch (error) {
            console.error('Failed to fetch infrastructure data:', error);
        } finally {
            setLoading(false);
        }
    };

    const fetchAnalytics = async () => {
        try {
            const response = await fetch('/api/infrastructure/analytics', {
                headers: {
                    'Accept': 'application/json',
                }
            });
            if (response.ok) {
                const data = await response.json();
                setAnalysis(data);
            }
        } catch (error) {
            console.error('Failed to fetch analytics:', error);
        }
    };

    const handleRealTimeUpdate = (data) => {
        setRealTimeData(prev => [...prev.slice(-19), data]);
        setMetrics(prev => ({
            ...prev,
            [data.serverCode]: data.status
        }));
    };

    const getStatusColor = (status) => {
        switch (status) {
            case 'excellent': return 'text-green-600';
            case 'good': return 'text-blue-600';
            case 'fair': return 'text-yellow-600';
            case 'poor': return 'text-orange-600';
            case 'critical': return 'text-red-600';
            default: return 'text-gray-600';
        }
    };

    const getStatusIcon = (status) => {
        switch (status) {
            case 'excellent':
            case 'good':
                return <CheckCircle className="h-5 w-5 text-green-500" />;
            case 'fair':
                return <AlertTriangle className="h-5 w-5 text-yellow-500" />;
            case 'poor':
            case 'critical':
                return <AlertCircle className="h-5 w-5 text-red-500" />;
            default:
                return <Activity className="h-5 w-5 text-gray-500" />;
        }
    };

    // Chart configurations
    const cpuChartData = {
        labels: Object.keys(metrics),
        datasets: [{
            label: 'CPU Usage %',
            data: Object.values(metrics).map(m => m?.metrics?.resources?.cpu_usage || 0),
            borderColor: 'rgb(59, 130, 246)',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            tension: 0.4
        }]
    };

    const memoryChartData = {
        labels: Object.keys(metrics),
        datasets: [{
            label: 'Memory Usage %',
            data: Object.values(metrics).map(m => m?.metrics?.resources?.memory_usage || 0),
            backgroundColor: 'rgba(147, 51, 234, 0.5)',
            borderColor: 'rgba(147, 51, 234, 1)',
            borderWidth: 1
        }]
    };

    const healthScoreData = {
        labels: ['Health Score'],
        datasets: [{
            data: [analysis?.health_score?.overall || 0, 100 - (analysis?.health_score?.overall || 0)],
            backgroundColor: [
                'rgba(34, 197, 94, 0.8)',
                'rgba(229, 231, 235, 0.3)'
            ],
            borderWidth: 0
        }]
    };

    const performanceRadarData = {
        labels: ['CPU', 'Memory', 'Disk', 'Network', 'Services'],
        datasets: Object.entries(metrics).slice(0, 3).map(([ server, data], index) => ({
            label: server,
            data: [
                100 - (data?.metrics?.resources?.cpu_usage || 0),
                100 - (data?.metrics?.resources?.memory_usage || 0),
                100 - (data?.metrics?.resources?.disk_usage || 0),
                90, // Network placeholder
                95  // Services placeholder
            ],
            borderColor: ['rgb(59, 130, 246)', 'rgb(147, 51, 234)', 'rgb(34, 197, 94)'][index],
            backgroundColor: ['rgba(59, 130, 246, 0.2)', 'rgba(147, 51, 234, 0.2)', 'rgba(34, 197, 94, 0.2)'][index],
        }))
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-screen">
                <div className="text-center">
                    <RefreshCw className="h-8 w-8 animate-spin mx-auto mb-4" />
                    <p>Loading infrastructure data...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-gray-50 p-6">
            {/* Header */}
            <div className="mb-8">
                <h1 className="text-3xl font-bold text-gray-900 mb-2">Infrastructure Analytics</h1>
                <div className="flex items-center justify-between">
                    <p className="text-gray-500">
                        Real-time monitoring and AI-powered insights
                    </p>
                    <div className="flex items-center gap-4">
                        <Button 
                            variant={autoRefresh ? "default" : "outline"}
                            onClick={() => setAutoRefresh(!autoRefresh)}
                            className="flex items-center gap-2"
                        >
                            <RefreshCw className={`h-4 w-4 ${autoRefresh ? 'animate-spin' : ''}`} />
                            Auto Refresh: {autoRefresh ? 'ON' : 'OFF'}
                        </Button>
                        <Button onClick={() => { fetchInfrastructureData(); fetchAnalytics(); }}>
                            Refresh Now
                        </Button>
                    </div>
                </div>
            </div>

            {/* Health Overview */}
            {analysis && (
                <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
                    <div className="bg-white rounded-lg p-6 shadow-sm">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-sm font-medium text-gray-500">Overall Health</h3>
                            {getStatusIcon(analysis.health_score?.status)}
                        </div>
                        <p className={`text-3xl font-bold ${getStatusColor(analysis.health_score?.status)}`}>
                            {analysis.health_score?.overall}%
                        </p>
                        <p className="text-xs text-gray-500 mt-2">
                            Status: {analysis.health_score?.status}
                        </p>
                    </div>

                    <div className="bg-white rounded-lg p-6 shadow-sm">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-sm font-medium text-gray-500">Active Servers</h3>
                            <Server className="h-5 w-5 text-blue-500" />
                        </div>
                        <p className="text-3xl font-bold text-gray-900">
                            {Object.keys(metrics).length}
                        </p>
                        <p className="text-xs text-gray-500 mt-2">
                            {Object.values(metrics).filter(m => m.status === 'healthy').length} healthy
                        </p>
                    </div>

                    <div className="bg-white rounded-lg p-6 shadow-sm">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-sm font-medium text-gray-500">Predictions</h3>
                            <TrendingUp className="h-5 w-5 text-purple-500" />
                        </div>
                        <p className="text-3xl font-bold text-gray-900">
                            {Object.keys(analysis.predictions || {}).length}
                        </p>
                        <p className="text-xs text-gray-500 mt-2">
                            Potential issues detected
                        </p>
                    </div>

                    <div className="bg-white rounded-lg p-6 shadow-sm">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-sm font-medium text-gray-500">AI Confidence</h3>
                            <Zap className="h-5 w-5 text-yellow-500" />
                        </div>
                        <p className="text-3xl font-bold text-gray-900">
                            {analysis.ai_insights?.confidence_level || 0}%
                        </p>
                        <p className="text-xs text-gray-500 mt-2">
                            Multi-model consensus
                        </p>
                    </div>
                </div>
            )}

            {/* Charts Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
                {/* CPU Usage Chart */}
                <div className="bg-white rounded-lg p-6 shadow-sm">
                    <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                        <Cpu className="h-5 w-5" />
                        CPU Usage Across Servers
                    </h3>
                    <Line 
                        data={cpuChartData} 
                        options={{
                            responsive: true,
                            plugins: {
                                legend: { display: false },
                                tooltip: {
                                    callbacks: {
                                        label: (context) => `${context.parsed.y}%`
                                    }
                                }
                            },
                            scales: {
                                y: {
                                    beginAtZero: true,
                                    max: 100,
                                    ticks: {
                                        callback: (value) => `${value}%`
                                    }
                                }
                            }
                        }}
                    />
                </div>

                {/* Memory Usage Chart */}
                <div className="bg-white rounded-lg p-6 shadow-sm">
                    <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                        <Database className="h-5 w-5" />
                        Memory Usage
                    </h3>
                    <Bar 
                        data={memoryChartData}
                        options={{
                            responsive: true,
                            plugins: {
                                legend: { display: false },
                                tooltip: {
                                    callbacks: {
                                        label: (context) => `${context.parsed.y}%`
                                    }
                                }
                            },
                            scales: {
                                y: {
                                    beginAtZero: true,
                                    max: 100,
                                    ticks: {
                                        callback: (value) => `${value}%`
                                    }
                                }
                            }
                        }}
                    />
                </div>

                {/* Health Score */}
                <div className="bg-white rounded-lg p-6 shadow-sm">
                    <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                        <Shield className="h-5 w-5" />
                        Infrastructure Health
                    </h3>
                    <div className="w-64 mx-auto">
                        <Doughnut 
                            data={healthScoreData}
                            options={{
                                responsive: true,
                                plugins: {
                                    legend: { display: false },
                                    tooltip: {
                                        callbacks: {
                                            label: (context) => 
                                                context.dataIndex === 0 
                                                    ? `Health: ${context.parsed}%` 
                                                    : ''
                                        }
                                    }
                                },
                                cutout: '70%'
                            }}
                        />
                        <div className="text-center mt-4">
                            <p className="text-2xl font-bold">{analysis?.health_score?.overall}%</p>
                            <p className="text-sm text-gray-500">{analysis?.health_score?.status}</p>
                        </div>
                    </div>
                </div>

                {/* Performance Radar */}
                <div className="bg-white rounded-lg p-6 shadow-sm">
                    <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                        <Network className="h-5 w-5" />
                        Performance Overview
                    </h3>
                    <Radar 
                        data={performanceRadarData}
                        options={{
                            responsive: true,
                            scales: {
                                r: {
                                    beginAtZero: true,
                                    max: 100
                                }
                            }
                        }}
                    />
                </div>
            </div>

            {/* Recommendations and Alerts */}
            {analysis && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    {/* AI Recommendations */}
                    <div className="bg-white rounded-lg p-6 shadow-sm">
                        <h3 className="text-lg font-semibold mb-4">AI Recommendations</h3>
                        <div className="space-y-3">
                            {Object.entries(analysis.recommendations || {}).slice(0, 5).map(([server, recs]) => (
                                <div key={server}>
                                    <h4 className="font-medium text-sm text-gray-700 mb-2">{server}</h4>
                                    {recs.map((rec, idx) => (
                                        <div key={idx} className="bg-gray-50 rounded p-3 mb-2">
                                            <div className="flex items-start gap-2">
                                                <span className={`px-2 py-1 text-xs rounded ${
                                                    rec.priority === 'critical' ? 'bg-red-100 text-red-700' :
                                                    rec.priority === 'high' ? 'bg-orange-100 text-orange-700' :
                                                    'bg-blue-100 text-blue-700'
                                                }`}>
                                                    {rec.priority}
                                                </span>
                                                <div className="flex-1">
                                                    <p className="text-sm text-gray-900">{rec.description}</p>
                                                    <p className="text-xs text-gray-500 mt-1">Impact: {rec.estimated_impact}</p>
                                                </div>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Anomaly Detection */}
                    <div className="bg-white rounded-lg p-6 shadow-sm">
                        <h3 className="text-lg font-semibold mb-4">Anomaly Detection</h3>
                        <div className="space-y-3">
                            {Object.entries(analysis.anomalies || {}).map(([server, anomalies]) => (
                                <div key={server}>
                                    <h4 className="font-medium text-sm text-gray-700 mb-2">{server}</h4>
                                    {anomalies.map((anomaly, idx) => (
                                        <div key={idx} className="bg-gray-50 rounded p-3 mb-2">
                                            <div className="flex items-center justify-between">
                                                <div className="flex items-center gap-2">
                                                    <AlertTriangle className={`h-4 w-4 ${
                                                        anomaly.severity === 'critical' ? 'text-red-500' :
                                                        anomaly.severity === 'high' ? 'text-orange-500' :
                                                        'text-yellow-500'
                                                    }`} />
                                                    <span className="text-sm font-medium">{anomaly.type}</span>
                                                </div>
                                                <span className="text-xs text-gray-500">
                                                    {format(new Date(anomaly.timestamp), 'HH:mm:ss')}
                                                </span>
                                            </div>
                                            {anomaly.change && (
                                                <p className="text-xs text-gray-600 mt-1">Change: {anomaly.change}</p>
                                            )}
                                        </div>
                                    ))}
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

export default InfrastructureDashboard;