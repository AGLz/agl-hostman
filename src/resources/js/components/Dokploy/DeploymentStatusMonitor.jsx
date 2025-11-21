import React, { useState, useEffect } from 'react';
import {
    CheckCircle,
    XCircle,
    Clock,
    RefreshCw,
    AlertTriangle,
    Activity
} from 'lucide-react';

function DeploymentStatusMonitor({ applicationId, refreshInterval = 5000 }) {
    const [application, setApplication] = useState(null);
    const [loading, setLoading] = useState(true);
    const [lastUpdate, setLastUpdate] = useState(null);

    useEffect(() => {
        fetchApplicationStatus();

        // Set up polling
        const interval = setInterval(() => {
            fetchApplicationStatus();
        }, refreshInterval);

        return () => clearInterval(interval);
    }, [applicationId, refreshInterval]);

    const fetchApplicationStatus = async () => {
        try {
            const response = await fetch(`/api/dokploy/applications/${applicationId}`, {
                headers: {
                    'Accept': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('api_token')}`,
                },
            });
            if (response.ok) {
                const data = await response.json();
                setApplication(data.data);
                setLastUpdate(new Date());
            }
        } catch (error) {
            console.error('Failed to fetch application status:', error);
        } finally {
            setLoading(false);
        }
    };

    const getStatusIcon = (status) => {
        switch (status) {
            case 'running':
                return <CheckCircle className="h-5 w-5 text-green-500" />;
            case 'error':
                return <XCircle className="h-5 w-5 text-red-500" />;
            case 'idle':
                return <Clock className="h-5 w-5 text-gray-500" />;
            case 'done':
                return <CheckCircle className="h-5 w-5 text-blue-500" />;
            default:
                return <AlertTriangle className="h-5 w-5 text-yellow-500" />;
        }
    };

    const getStatusColor = (status) => {
        switch (status) {
            case 'running':
                return 'bg-green-50 border-green-200 text-green-800';
            case 'error':
                return 'bg-red-50 border-red-200 text-red-800';
            case 'idle':
                return 'bg-gray-50 border-gray-200 text-gray-800';
            case 'done':
                return 'bg-blue-50 border-blue-200 text-blue-800';
            default:
                return 'bg-yellow-50 border-yellow-200 text-yellow-800';
        }
    };

    const formatTime = (date) => {
        if (!date) return 'Never';
        const now = new Date();
        const diff = Math.floor((now - date) / 1000); // seconds

        if (diff < 60) return `${diff}s ago`;
        if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
        if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
        return `${Math.floor(diff / 86400)}d ago`;
    };

    if (loading) {
        return (
            <div className="bg-white rounded-lg shadow p-6">
                <div className="flex items-center justify-center">
                    <RefreshCw className="h-6 w-6 animate-spin text-gray-400" />
                    <span className="ml-2 text-gray-500">Loading deployment status...</span>
                </div>
            </div>
        );
    }

    if (!application) {
        return (
            <div className="bg-white rounded-lg shadow p-6">
                <p className="text-gray-500 text-center">Application not found</p>
            </div>
        );
    }

    return (
        <div className="bg-white rounded-lg shadow">
            {/* Header */}
            <div className="px-6 py-4 border-b">
                <div className="flex items-center justify-between">
                    <h3 className="text-lg font-medium text-gray-900 flex items-center gap-2">
                        <Activity className="h-5 w-5" />
                        Deployment Status
                    </h3>
                    <div className="text-xs text-gray-500">
                        Last updated: {formatTime(lastUpdate)}
                    </div>
                </div>
            </div>

            {/* Status Card */}
            <div className="p-6">
                <div className={`border rounded-lg p-6 ${getStatusColor(application.applicationStatus)}`}>
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-3">
                            {getStatusIcon(application.applicationStatus)}
                            <div>
                                <h4 className="font-medium text-lg">{application.name}</h4>
                                <p className="text-sm opacity-80">{application.appName}</p>
                            </div>
                        </div>
                        <div className="text-right">
                            <div className="text-2xl font-bold capitalize">
                                {application.applicationStatus || 'unknown'}
                            </div>
                        </div>
                    </div>

                    {/* Application Details */}
                    <div className="grid grid-cols-2 gap-4 pt-4 border-t border-current border-opacity-20">
                        {application.dockerImage && (
                            <div>
                                <div className="text-xs opacity-60 mb-1">Docker Image</div>
                                <div className="text-sm font-mono truncate" title={application.dockerImage}>
                                    {application.dockerImage.split('/').pop()}
                                </div>
                            </div>
                        )}
                        {application.sourceType && (
                            <div>
                                <div className="text-xs opacity-60 mb-1">Source Type</div>
                                <div className="text-sm font-medium capitalize">{application.sourceType}</div>
                            </div>
                        )}
                        {application.replicas !== undefined && (
                            <div>
                                <div className="text-xs opacity-60 mb-1">Replicas</div>
                                <div className="text-sm font-medium">{application.replicas}</div>
                            </div>
                        )}
                        {application.createdAt && (
                            <div>
                                <div className="text-xs opacity-60 mb-1">Created</div>
                                <div className="text-sm font-medium">
                                    {new Date(application.createdAt).toLocaleDateString()}
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* Recent Activity */}
                {application.lastDeployment && (
                    <div className="mt-6">
                        <h4 className="text-sm font-medium text-gray-700 mb-3">Recent Activity</h4>
                        <div className="space-y-2">
                            <ActivityItem
                                type="deployment"
                                status="success"
                                message="Application deployed successfully"
                                timestamp={application.lastDeployment}
                            />
                        </div>
                    </div>
                )}

                {/* Environment Variables (if any) */}
                {application.env && (
                    <div className="mt-6">
                        <h4 className="text-sm font-medium text-gray-700 mb-3">Environment</h4>
                        <div className="bg-gray-50 rounded-lg p-4 text-xs font-mono text-gray-600">
                            {Object.keys(application.env || {}).length} environment variables configured
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}

function ActivityItem({ type, status, message, timestamp }) {
    const getStatusColor = () => {
        switch (status) {
            case 'success':
                return 'text-green-600';
            case 'error':
                return 'text-red-600';
            case 'pending':
                return 'text-yellow-600';
            default:
                return 'text-gray-600';
        }
    };

    return (
        <div className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg">
            <div className={`mt-0.5 ${getStatusColor()}`}>
                {status === 'success' && <CheckCircle className="h-4 w-4" />}
                {status === 'error' && <XCircle className="h-4 w-4" />}
                {status === 'pending' && <Clock className="h-4 w-4" />}
            </div>
            <div className="flex-1">
                <p className="text-sm text-gray-900">{message}</p>
                <p className="text-xs text-gray-500 mt-1">
                    {new Date(timestamp).toLocaleString()}
                </p>
            </div>
        </div>
    );
}

export default DeploymentStatusMonitor;
