import React from 'react';
import { Link } from '@inertiajs/react';
import EnvironmentBadge from './EnvironmentBadge';
import { Server, Activity, Clock } from 'lucide-react';
import { format } from 'date-fns';

export default function ApplicationCard({ application }) {
    const isRunning = application.status === 'running';
    const lastDeployment = application.last_deployment;

    return (
        <Link
            href={`/dokploy/applications/${application.id}`}
            className="block bg-white dark:bg-gray-800 rounded-lg shadow hover:shadow-lg transition"
        >
            {/* Header */}
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
                <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3">
                        <div className={`p-2 rounded-lg ${
                            isRunning
                                ? 'bg-green-100 dark:bg-green-900'
                                : 'bg-red-100 dark:bg-red-900'
                        }`}>
                            <Server className={`w-5 h-5 ${
                                isRunning
                                    ? 'text-green-600 dark:text-green-300'
                                    : 'text-red-600 dark:text-red-300'
                            }`} />
                        </div>
                        <div>
                            <h3 className="text-lg font-bold text-gray-900 dark:text-white">
                                {application.name}
                            </h3>
                            <p className="text-sm text-gray-500 dark:text-gray-400">
                                {application.app_name}
                            </p>
                        </div>
                    </div>
                    <EnvironmentBadge environment={application.environment} />
                </div>

                {application.description && (
                    <p className="mt-3 text-sm text-gray-600 dark:text-gray-400 line-clamp-2">
                        {application.description}
                    </p>
                )}
            </div>

            {/* Status */}
            <div className="p-6 space-y-4">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                        <Activity className="w-4 h-4" />
                        <span className="text-sm">Status</span>
                    </div>
                    <span className={`px-3 py-1 rounded-full text-xs font-medium ${
                        isRunning
                            ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                            : application.status === 'error'
                            ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                            : 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                    }`}>
                        {application.status || 'Unknown'}
                    </span>
                </div>

                {lastDeployment && (
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                            <Clock className="w-4 h-4" />
                            <span className="text-sm">Last Deployment</span>
                        </div>
                        <span className="text-sm font-medium text-gray-900 dark:text-white">
                            {format(new Date(lastDeployment), 'MMM dd, HH:mm')}
                        </span>
                    </div>
                )}

                {/* Build info */}
                {application.build_type && (
                    <div className="pt-3 border-t border-gray-200 dark:border-gray-700">
                        <div className="flex items-center justify-between text-xs">
                            <span className="text-gray-500 dark:text-gray-400">Build Type:</span>
                            <span className="font-medium text-gray-700 dark:text-gray-300">
                                {application.build_type}
                            </span>
                        </div>
                        {application.docker_image && (
                            <div className="flex items-center justify-between text-xs mt-1">
                                <span className="text-gray-500 dark:text-gray-400">Image:</span>
                                <span className="font-mono text-gray-700 dark:text-gray-300 truncate ml-2">
                                    {application.docker_image}
                                </span>
                            </div>
                        )}
                    </div>
                )}
            </div>

            {/* Footer with quick actions */}
            <div className="px-6 py-3 bg-gray-50 dark:bg-gray-700 rounded-b-lg">
                <div className="flex items-center justify-between text-xs">
                    <span className="text-gray-500 dark:text-gray-400">
                        {application.replicas || 1} replica{application.replicas !== 1 ? 's' : ''}
                    </span>
                    <div className="flex items-center gap-2">
                        {application.domains_count > 0 && (
                            <span className="text-gray-500 dark:text-gray-400">
                                {application.domains_count} domain{application.domains_count !== 1 ? 's' : ''}
                            </span>
                        )}
                    </div>
                </div>
            </div>
        </Link>
    );
}
