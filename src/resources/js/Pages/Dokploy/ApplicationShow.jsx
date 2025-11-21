import React, { useState } from 'react';
import { Head, Link } from '@inertiajs/react';
import DeploymentTimeline from '@/Components/Dokploy/DeploymentTimeline';
import DeploymentLogs from '@/Components/Dokploy/DeploymentLogs';
import DomainManager from '@/Components/Dokploy/DomainManager';
import EnvironmentBadge from '@/Components/Dokploy/EnvironmentBadge';
import DeployButton from '@/Components/Dokploy/DeployButton';
import RollbackButton from '@/Components/Dokploy/RollbackButton';
import { useDeployment } from '@/hooks/useDeployment';
import { ChevronLeft, Play, StopCircle, RotateCcw, Settings } from 'lucide-react';

export default function ApplicationShow({ application, deployments, domains, project }) {
    const [activeTab, setActiveTab] = useState('deployments');
    const { deploy, stop, restart, isLoading } = useDeployment(application.id);

    const latestDeployment = deployments[0];
    const isRunning = application.status === 'running';

    return (
        <>
            <Head title={`Application: ${application.name}`} />

            <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
                {/* Header */}
                <div className="bg-white dark:bg-gray-800 shadow">
                    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                        <div className="flex items-center gap-4">
                            <Link
                                href={`/dokploy/projects/${project.id}`}
                                className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition"
                            >
                                <ChevronLeft className="w-6 h-6 text-gray-600 dark:text-gray-300" />
                            </Link>
                            <div className="flex-1">
                                <div className="flex items-center gap-3">
                                    <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
                                        {application.name}
                                    </h1>
                                    <EnvironmentBadge environment={application.environment} />
                                </div>
                                <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                                    {project.name} / {application.name}
                                </p>
                            </div>
                            <div className="flex items-center gap-3">
                                <DeployButton
                                    applicationId={application.id}
                                    onDeploy={deploy}
                                    disabled={isLoading}
                                />
                                {isRunning ? (
                                    <button
                                        onClick={stop}
                                        disabled={isLoading}
                                        className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 transition"
                                    >
                                        <StopCircle className="w-5 h-5" />
                                        Stop
                                    </button>
                                ) : (
                                    <button
                                        onClick={() => deploy()}
                                        disabled={isLoading}
                                        className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition"
                                    >
                                        <Play className="w-5 h-5" />
                                        Start
                                    </button>
                                )}
                                <button
                                    onClick={restart}
                                    disabled={isLoading}
                                    className="flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 transition"
                                >
                                    <RotateCcw className="w-5 h-5 text-gray-600 dark:text-gray-300" />
                                    Restart
                                </button>
                                <button className="p-2 rounded-lg border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition">
                                    <Settings className="w-5 h-5 text-gray-600 dark:text-gray-300" />
                                </button>
                            </div>
                        </div>

                        {/* Status Cards */}
                        <div className="mt-6 grid grid-cols-1 md:grid-cols-4 gap-4">
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Status</p>
                                <p className={`mt-1 text-2xl font-semibold ${
                                    isRunning ? 'text-green-600' : 'text-red-600'
                                }`}>
                                    {application.status || 'Unknown'}
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Total Deployments</p>
                                <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {deployments.length}
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Success Rate</p>
                                <p className="mt-1 text-2xl font-semibold text-green-600">
                                    {deployments.length > 0
                                        ? Math.round((deployments.filter(d => d.status === 'done').length / deployments.length) * 100)
                                        : 0}%
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Last Deployment</p>
                                <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {latestDeployment?.created_at
                                        ? new Date(latestDeployment.created_at).toLocaleDateString()
                                        : 'Never'}
                                </p>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Tabs */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-6">
                    <div className="border-b border-gray-200 dark:border-gray-700">
                        <nav className="flex gap-8">
                            {['deployments', 'logs', 'domains', 'settings'].map((tab) => (
                                <button
                                    key={tab}
                                    onClick={() => setActiveTab(tab)}
                                    className={`pb-4 px-1 border-b-2 font-medium text-sm transition ${
                                        activeTab === tab
                                            ? 'border-blue-500 text-blue-600 dark:text-blue-400'
                                            : 'border-transparent text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300'
                                    }`}
                                >
                                    {tab.charAt(0).toUpperCase() + tab.slice(1)}
                                </button>
                            ))}
                        </nav>
                    </div>
                </div>

                {/* Tab Content */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 pb-12">
                    {activeTab === 'deployments' && (
                        <div className="space-y-6">
                            <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                                <div className="flex items-center justify-between mb-4">
                                    <h2 className="text-xl font-bold text-gray-900 dark:text-white">
                                        Deployment History
                                    </h2>
                                    {deployments.length > 1 && (
                                        <RollbackButton
                                            applicationId={application.id}
                                            deployments={deployments.slice(1, 11)}
                                            currentDeployment={latestDeployment}
                                        />
                                    )}
                                </div>
                                <DeploymentTimeline deployments={deployments} />
                            </div>
                        </div>
                    )}

                    {activeTab === 'logs' && (
                        <div className="bg-white dark:bg-gray-800 rounded-lg shadow">
                            <DeploymentLogs applicationId={application.id} />
                        </div>
                    )}

                    {activeTab === 'domains' && (
                        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                            <DomainManager
                                applicationId={application.id}
                                domains={domains}
                            />
                        </div>
                    )}

                    {activeTab === 'settings' && (
                        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                            <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
                                Application Settings
                            </h2>
                            <p className="text-gray-500 dark:text-gray-400">
                                Settings panel coming soon...
                            </p>
                        </div>
                    )}
                </div>
            </div>
        </>
    );
}
