import React from 'react';
import { Link } from '@inertiajs/react';
import EnvironmentBadge from './EnvironmentBadge';
import { FolderOpen, Activity, Calendar } from 'lucide-react';
import { format } from 'date-fns';

export default function ProjectCard({ project, viewMode = 'grid' }) {
    const activeApps = project.applications?.filter(app => app.status === 'running').length || 0;
    const totalApps = project.applications?.length || 0;

    if (viewMode === 'list') {
        return (
            <Link
                href={`/dokploy/projects/${project.id}`}
                className="block bg-white dark:bg-gray-800 rounded-lg shadow hover:shadow-lg transition p-6"
            >
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4 flex-1">
                        <div className="p-3 bg-blue-100 dark:bg-blue-900 rounded-lg">
                            <FolderOpen className="w-6 h-6 text-blue-600 dark:text-blue-300" />
                        </div>
                        <div className="flex-1">
                            <h3 className="text-lg font-bold text-gray-900 dark:text-white">
                                {project.name}
                            </h3>
                            {project.description && (
                                <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                                    {project.description}
                                </p>
                            )}
                        </div>
                    </div>

                    <div className="flex items-center gap-6">
                        <div className="text-center">
                            <p className="text-2xl font-bold text-gray-900 dark:text-white">
                                {activeApps}/{totalApps}
                            </p>
                            <p className="text-xs text-gray-500 dark:text-gray-400">Active Apps</p>
                        </div>

                        {project.updated_at && (
                            <div className="text-right">
                                <p className="text-sm text-gray-600 dark:text-gray-300">
                                    {format(new Date(project.updated_at), 'MMM dd, yyyy')}
                                </p>
                                <p className="text-xs text-gray-500 dark:text-gray-400">Last Updated</p>
                            </div>
                        )}

                        <div className={`px-3 py-1 rounded-full text-xs font-medium ${
                            project.status === 'active'
                                ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                                : 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200'
                        }`}>
                            {project.status || 'Unknown'}
                        </div>
                    </div>
                </div>
            </Link>
        );
    }

    return (
        <Link
            href={`/dokploy/projects/${project.id}`}
            className="block bg-white dark:bg-gray-800 rounded-lg shadow hover:shadow-lg transition"
        >
            {/* Header */}
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
                <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3">
                        <div className="p-2 bg-blue-100 dark:bg-blue-900 rounded-lg">
                            <FolderOpen className="w-5 h-5 text-blue-600 dark:text-blue-300" />
                        </div>
                        <div>
                            <h3 className="text-lg font-bold text-gray-900 dark:text-white">
                                {project.name}
                            </h3>
                            <div className={`mt-1 inline-flex px-2 py-0.5 rounded-full text-xs font-medium ${
                                project.status === 'active'
                                    ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                                    : 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200'
                            }`}>
                                {project.status || 'Unknown'}
                            </div>
                        </div>
                    </div>
                </div>

                {project.description && (
                    <p className="mt-3 text-sm text-gray-600 dark:text-gray-400 line-clamp-2">
                        {project.description}
                    </p>
                )}
            </div>

            {/* Stats */}
            <div className="p-6 space-y-4">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                        <Activity className="w-4 h-4" />
                        <span className="text-sm">Applications</span>
                    </div>
                    <div className="text-right">
                        <span className="text-lg font-bold text-gray-900 dark:text-white">
                            {activeApps}/{totalApps}
                        </span>
                        <span className="ml-1 text-xs text-gray-500 dark:text-gray-400">active</span>
                    </div>
                </div>

                {project.updated_at && (
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                            <Calendar className="w-4 h-4" />
                            <span className="text-sm">Last Updated</span>
                        </div>
                        <span className="text-sm font-medium text-gray-900 dark:text-white">
                            {format(new Date(project.updated_at), 'MMM dd, yyyy')}
                        </span>
                    </div>
                )}

                {/* Environment badges */}
                {project.applications && project.applications.length > 0 && (
                    <div className="pt-3 border-t border-gray-200 dark:border-gray-700">
                        <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">Environments:</p>
                        <div className="flex flex-wrap gap-2">
                            {[...new Set(project.applications.map(app => app.environment))].map(env => (
                                <EnvironmentBadge key={env} environment={env} size="sm" />
                            ))}
                        </div>
                    </div>
                )}
            </div>
        </Link>
    );
}
