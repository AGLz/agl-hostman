import React, { useState } from 'react';
import { Head, Link } from '@inertiajs/react';
import ApplicationCard from '@/Components/Dokploy/ApplicationCard';
import DeploymentPipeline from '@/Components/Dokploy/DeploymentPipeline';
import { ChevronLeft, Plus, Settings } from 'lucide-react';

export default function ProjectShow({ project, applications, deployments }) {
    const [selectedEnvironment, setSelectedEnvironment] = useState('all');

    const filteredApplications = selectedEnvironment === 'all'
        ? applications
        : applications.filter(app => app.environment === selectedEnvironment);

    return (
        <>
            <Head title={`Project: ${project.name}`} />

            <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
                {/* Header */}
                <div className="bg-white dark:bg-gray-800 shadow">
                    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                        <div className="flex items-center gap-4">
                            <Link
                                href="/dokploy"
                                className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition"
                            >
                                <ChevronLeft className="w-6 h-6 text-gray-600 dark:text-gray-300" />
                            </Link>
                            <div className="flex-1">
                                <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
                                    {project.name}
                                </h1>
                                {project.description && (
                                    <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                                        {project.description}
                                    </p>
                                )}
                            </div>
                            <div className="flex items-center gap-3">
                                <button className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition">
                                    <Plus className="w-5 h-5" />
                                    New Application
                                </button>
                                <button className="p-2 rounded-lg border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition">
                                    <Settings className="w-5 h-5 text-gray-600 dark:text-gray-300" />
                                </button>
                            </div>
                        </div>

                        {/* Project Info */}
                        <div className="mt-6 grid grid-cols-1 md:grid-cols-3 gap-4">
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Applications</p>
                                <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {applications.length}
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Active Deployments</p>
                                <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {deployments.filter(d => d.status === 'running').length}
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Last Deployment</p>
                                <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {deployments[0]?.created_at ? new Date(deployments[0].created_at).toLocaleDateString() : 'Never'}
                                </p>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Deployment Pipeline */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                    <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                        <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
                            Deployment Pipeline
                        </h2>
                        <DeploymentPipeline
                            projectId={project.id}
                            deployments={deployments}
                        />
                    </div>
                </div>

                {/* Environment Filter */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="flex gap-2">
                        {['all', 'dev', 'qa', 'uat', 'prod'].map((env) => (
                            <button
                                key={env}
                                onClick={() => setSelectedEnvironment(env)}
                                className={`px-4 py-2 rounded-lg font-medium transition ${
                                    selectedEnvironment === env
                                        ? 'bg-blue-600 text-white'
                                        : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'
                                }`}
                            >
                                {env === 'all' ? 'All Environments' : env.toUpperCase()}
                            </button>
                        ))}
                    </div>
                </div>

                {/* Applications List */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 pb-12">
                    {filteredApplications.length === 0 ? (
                        <div className="text-center py-12 bg-white dark:bg-gray-800 rounded-lg">
                            <p className="text-gray-500 dark:text-gray-400 text-lg">
                                No applications in this environment
                            </p>
                        </div>
                    ) : (
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                            {filteredApplications.map((application) => (
                                <ApplicationCard
                                    key={application.id}
                                    application={application}
                                />
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </>
    );
}
