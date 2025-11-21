import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Settings, Activity, Webhook, Info } from 'lucide-react';
import DokployApplicationList from '@/components/Dokploy/DokployApplicationList';
import DokployApplicationForm from '@/components/Dokploy/DokployApplicationForm';
import DeploymentStatusMonitor from '@/components/Dokploy/DeploymentStatusMonitor';
import HarborWebhookConfig from '@/components/Dokploy/HarborWebhookConfig';

function DokployDashboard() {
    const [activeTab, setActiveTab] = useState('applications');
    const [showForm, setShowForm] = useState(false);
    const [editApplication, setEditApplication] = useState(null);
    const [selectedApplicationId, setSelectedApplicationId] = useState(null);

    const handleCreateClick = () => {
        setEditApplication(null);
        setShowForm(true);
    };

    const handleEditClick = (application) => {
        setEditApplication(application);
        setShowForm(true);
    };

    const handleFormClose = () => {
        setShowForm(false);
        setEditApplication(null);
    };

    const handleFormSuccess = () => {
        // Refresh the application list by forcing a re-render
        setShowForm(false);
        setEditApplication(null);
    };

    const tabs = [
        { id: 'applications', label: 'Applications', icon: Activity },
        { id: 'monitor', label: 'Monitor', icon: Settings },
        { id: 'webhooks', label: 'Webhooks', icon: Webhook },
    ];

    return (
        <div>
            {/* Header */}
            <div className="bg-white border-b">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="py-6">
                        <div className="flex items-center justify-between">
                            <div>
                                <h1 className="text-3xl font-bold text-gray-900">Dokploy Management</h1>
                                <p className="mt-1 text-sm text-gray-500">
                                    Manage Docker applications and deployments
                                </p>
                            </div>
                            <div className="flex items-center gap-3">
                                <a
                                    href="https://dok.aglz.io"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="inline-flex items-center gap-2 px-4 py-2 text-sm border border-gray-300 rounded-md hover:bg-gray-50"
                                >
                                    Open Dokploy
                                    <Info className="h-4 w-4" />
                                </a>
                            </div>
                        </div>
                    </div>

                    {/* Tabs */}
                    <div className="flex space-x-8 border-t">
                        {tabs.map((tab) => {
                            const Icon = tab.icon;
                            return (
                                <button
                                    key={tab.id}
                                    onClick={() => setActiveTab(tab.id)}
                                    className={`flex items-center gap-2 py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
                                        activeTab === tab.id
                                            ? 'border-blue-500 text-blue-600'
                                            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                                    }`}
                                >
                                    <Icon className="h-5 w-5" />
                                    {tab.label}
                                </button>
                            );
                        })}
                    </div>
                </div>
            </div>

            {/* Content */}
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                {/* Applications Tab */}
                {activeTab === 'applications' && (
                    <div className="space-y-6">
                        <DokployApplicationList
                            onCreateClick={handleCreateClick}
                            onEditClick={handleEditClick}
                        />
                    </div>
                )}

                {/* Monitor Tab */}
                {activeTab === 'monitor' && (
                    <div className="space-y-6">
                        {/* Application Selector */}
                        <div className="bg-white rounded-lg shadow p-6">
                            <h3 className="text-lg font-medium text-gray-900 mb-4">
                                Select Application to Monitor
                            </h3>
                            <ApplicationSelector
                                onSelect={setSelectedApplicationId}
                                selectedId={selectedApplicationId}
                            />
                        </div>

                        {/* Status Monitor */}
                        {selectedApplicationId ? (
                            <DeploymentStatusMonitor
                                applicationId={selectedApplicationId}
                                refreshInterval={5000}
                            />
                        ) : (
                            <div className="bg-white rounded-lg shadow p-12 text-center">
                                <Activity className="h-12 w-12 mx-auto text-gray-300 mb-4" />
                                <p className="text-gray-500">
                                    Select an application to monitor its deployment status
                                </p>
                            </div>
                        )}
                    </div>
                )}

                {/* Webhooks Tab */}
                {activeTab === 'webhooks' && (
                    <div className="space-y-6">
                        <HarborWebhookConfig />

                        {/* Additional Webhook Info */}
                        <div className="bg-blue-50 border border-blue-200 rounded-lg p-6">
                            <h4 className="text-sm font-medium text-blue-900 mb-2">
                                How Webhooks Work
                            </h4>
                            <ul className="space-y-2 text-sm text-blue-800">
                                <li className="flex gap-2">
                                    <span className="text-blue-600">1.</span>
                                    <span>Push Docker image to Harbor registry (harbor.aglz.io:5000)</span>
                                </li>
                                <li className="flex gap-2">
                                    <span className="text-blue-600">2.</span>
                                    <span>Harbor sends PUSH_ARTIFACT webhook to this application</span>
                                </li>
                                <li className="flex gap-2">
                                    <span className="text-blue-600">3.</span>
                                    <span>Application matches image to Dokploy applications</span>
                                </li>
                                <li className="flex gap-2">
                                    <span className="text-blue-600">4.</span>
                                    <span>Triggers automatic redeployment on Dokploy (dok.aglz.io)</span>
                                </li>
                                <li className="flex gap-2">
                                    <span className="text-blue-600">5.</span>
                                    <span>Monitor deployment status in real-time on the Monitor tab</span>
                                </li>
                            </ul>
                        </div>
                    </div>
                )}
            </div>

            {/* Application Form Modal */}
            {showForm && (
                <DokployApplicationForm
                    onClose={handleFormClose}
                    onSuccess={handleFormSuccess}
                    editApplication={editApplication}
                />
            )}
        </div>
    );
}

function ApplicationSelector({ onSelect, selectedId }) {
    const [applications, setApplications] = useState([]);
    const [loading, setLoading] = useState(true);

    React.useEffect(() => {
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

    if (loading) {
        return <p className="text-sm text-gray-500">Loading applications...</p>;
    }

    if (applications.length === 0) {
        return (
            <p className="text-sm text-gray-500">
                No applications found. Create one in the Applications tab.
            </p>
        );
    }

    return (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {applications.map((app) => (
                <button
                    key={app.applicationId}
                    onClick={() => onSelect(app.applicationId)}
                    className={`text-left p-4 border rounded-lg transition-all ${
                        selectedId === app.applicationId
                            ? 'border-blue-500 bg-blue-50 ring-2 ring-blue-200'
                            : 'border-gray-200 hover:border-gray-300 hover:bg-gray-50'
                    }`}
                >
                    <h4 className="font-medium text-gray-900 mb-1">{app.name}</h4>
                    <p className="text-xs text-gray-500 truncate">{app.appName}</p>
                    {app.applicationStatus && (
                        <span
                            className={`inline-block mt-2 px-2 py-1 text-xs rounded-full ${
                                app.applicationStatus === 'running'
                                    ? 'bg-green-100 text-green-800'
                                    : app.applicationStatus === 'error'
                                    ? 'bg-red-100 text-red-800'
                                    : 'bg-gray-100 text-gray-800'
                            }`}
                        >
                            {app.applicationStatus}
                        </span>
                    )}
                </button>
            ))}
        </div>
    );
}

export default DokployDashboard;
