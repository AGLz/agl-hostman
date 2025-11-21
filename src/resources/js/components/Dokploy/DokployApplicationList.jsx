import React, { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import {
    Server,
    Play,
    Square,
    RefreshCw,
    Trash2,
    ExternalLink,
    Plus,
    Search,
    Filter
} from 'lucide-react';

function DokployApplicationList({ onCreateClick, onEditClick }) {
    const [applications, setApplications] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [filterStatus, setFilterStatus] = useState('all');

    useEffect(() => {
        fetchApplications();
    }, []);

    const fetchApplications = async () => {
        setLoading(true);
        try {
            const response = await fetch('/api/dokploy/applications', {
                headers: {
                    'Accept': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('api_token')}`,
                },
            });
            if (response.ok) {
                const data = await response.json();
                setApplications(data.data || []);
            }
        } catch (error) {
            console.error('Failed to fetch applications:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleAction = async (applicationId, action) => {
        try {
            const response = await fetch(`/api/dokploy/applications/${applicationId}/${action}`, {
                method: 'POST',
                headers: {
                    'Accept': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('api_token')}`,
                },
            });
            if (response.ok) {
                const data = await response.json();
                console.log(`${action} triggered:`, data);
                // Refresh list after action
                fetchApplications();
            }
        } catch (error) {
            console.error(`Failed to ${action} application:`, error);
        }
    };

    const handleDelete = async (applicationId) => {
        if (!confirm('Are you sure you want to delete this application?')) {
            return;
        }

        try {
            const response = await fetch(`/api/dokploy/applications/${applicationId}`, {
                method: 'DELETE',
                headers: {
                    'Accept': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('api_token')}`,
                },
            });
            if (response.ok) {
                fetchApplications();
            }
        } catch (error) {
            console.error('Failed to delete application:', error);
        }
    };

    const filteredApplications = applications.filter(app => {
        const matchesSearch = app.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                             app.dockerImage?.toLowerCase().includes(searchTerm.toLowerCase());
        const matchesFilter = filterStatus === 'all' || app.applicationStatus === filterStatus;
        return matchesSearch && matchesFilter;
    });

    const getStatusColor = (status) => {
        switch (status) {
            case 'running':
                return 'bg-green-100 text-green-800';
            case 'idle':
                return 'bg-gray-100 text-gray-800';
            case 'done':
                return 'bg-blue-100 text-blue-800';
            case 'error':
                return 'bg-red-100 text-red-800';
            default:
                return 'bg-gray-100 text-gray-800';
        }
    };

    return (
        <div className="bg-white shadow rounded-lg">
            {/* Header */}
            <div className="px-6 py-4 border-b">
                <div className="flex items-center justify-between mb-4">
                    <h2 className="text-lg font-medium text-gray-900">Applications</h2>
                    <Button onClick={onCreateClick} className="flex items-center gap-2">
                        <Plus className="h-4 w-4" />
                        New Application
                    </Button>
                </div>

                {/* Search and Filter */}
                <div className="flex gap-4">
                    <div className="flex-1 relative">
                        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                        <input
                            type="text"
                            placeholder="Search applications..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        />
                    </div>
                    <select
                        value={filterStatus}
                        onChange={(e) => setFilterStatus(e.target.value)}
                        className="px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    >
                        <option value="all">All Status</option>
                        <option value="running">Running</option>
                        <option value="idle">Idle</option>
                        <option value="done">Done</option>
                        <option value="error">Error</option>
                    </select>
                    <Button
                        variant="outline"
                        onClick={fetchApplications}
                        className="flex items-center gap-2"
                    >
                        <RefreshCw className="h-4 w-4" />
                        Refresh
                    </Button>
                </div>
            </div>

            {/* Applications List */}
            <div className="p-6">
                {loading ? (
                    <div className="text-center py-8">
                        <RefreshCw className="h-8 w-8 animate-spin mx-auto text-gray-400 mb-2" />
                        <p className="text-gray-500">Loading applications...</p>
                    </div>
                ) : filteredApplications.length === 0 ? (
                    <div className="text-center py-8">
                        <Server className="h-12 w-12 mx-auto text-gray-300 mb-2" />
                        <p className="text-gray-500 mb-4">No applications found</p>
                        <Button onClick={onCreateClick}>Create your first application</Button>
                    </div>
                ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {filteredApplications.map(app => (
                            <ApplicationCard
                                key={app.applicationId}
                                application={app}
                                onStart={() => handleAction(app.applicationId, 'start')}
                                onStop={() => handleAction(app.applicationId, 'stop')}
                                onRedeploy={() => handleAction(app.applicationId, 'redeploy')}
                                onDelete={() => handleDelete(app.applicationId)}
                                onEdit={() => onEditClick && onEditClick(app)}
                            />
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}

function ApplicationCard({ application, onStart, onStop, onRedeploy, onDelete, onEdit }) {
    const getStatusColor = (status) => {
        switch (status) {
            case 'running':
                return 'bg-green-100 text-green-800';
            case 'idle':
                return 'bg-gray-100 text-gray-800';
            case 'done':
                return 'bg-blue-100 text-blue-800';
            case 'error':
                return 'bg-red-100 text-red-800';
            default:
                return 'bg-gray-100 text-gray-800';
        }
    };

    return (
        <div className="border rounded-lg p-4 hover:shadow-md transition-shadow">
            {/* Header */}
            <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-2">
                    <Server className="h-4 w-4 text-gray-500" />
                    <h3 className="font-medium text-gray-900">{application.name}</h3>
                </div>
                <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(application.applicationStatus)}`}>
                    {application.applicationStatus || 'idle'}
                </span>
            </div>

            {/* Details */}
            <div className="space-y-2 mb-4">
                {application.dockerImage && (
                    <p className="text-xs text-gray-600 truncate" title={application.dockerImage}>
                        <strong>Image:</strong> {application.dockerImage}
                    </p>
                )}
                {application.appName && (
                    <p className="text-xs text-gray-600">
                        <strong>App:</strong> {application.appName}
                    </p>
                )}
                {application.description && (
                    <p className="text-xs text-gray-500 line-clamp-2">
                        {application.description}
                    </p>
                )}
            </div>

            {/* Actions */}
            <div className="flex flex-wrap gap-2 pt-3 border-t">
                <Button
                    size="sm"
                    variant="outline"
                    onClick={onStart}
                    className="flex-1 min-w-0"
                    title="Start"
                >
                    <Play className="h-3 w-3" />
                </Button>
                <Button
                    size="sm"
                    variant="outline"
                    onClick={onStop}
                    className="flex-1 min-w-0"
                    title="Stop"
                >
                    <Square className="h-3 w-3" />
                </Button>
                <Button
                    size="sm"
                    variant="outline"
                    onClick={onRedeploy}
                    className="flex-1 min-w-0"
                    title="Redeploy"
                >
                    <RefreshCw className="h-3 w-3" />
                </Button>
                {onEdit && (
                    <Button
                        size="sm"
                        variant="outline"
                        onClick={onEdit}
                        className="flex-1 min-w-0"
                        title="Edit"
                    >
                        <ExternalLink className="h-3 w-3" />
                    </Button>
                )}
                <Button
                    size="sm"
                    variant="outline"
                    onClick={onDelete}
                    className="text-red-600 hover:bg-red-50"
                    title="Delete"
                >
                    <Trash2 className="h-3 w-3" />
                </Button>
            </div>
        </div>
    );
}

export default DokployApplicationList;
