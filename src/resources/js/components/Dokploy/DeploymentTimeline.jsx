import React from 'react';
import { CheckCircle, XCircle, Clock, AlertCircle, GitCommit } from 'lucide-react';
import { format, formatDistanceToNow } from 'date-fns';

export default function DeploymentTimeline({ deployments }) {
    const getStatusIcon = (status) => {
        switch (status) {
            case 'done':
                return { Icon: CheckCircle, color: 'text-green-600', bg: 'bg-green-100 dark:bg-green-900' };
            case 'error':
                return { Icon: XCircle, color: 'text-red-600', bg: 'bg-red-100 dark:bg-red-900' };
            case 'running':
                return { Icon: Clock, color: 'text-yellow-600', bg: 'bg-yellow-100 dark:bg-yellow-900' };
            default:
                return { Icon: AlertCircle, color: 'text-gray-600', bg: 'bg-gray-100 dark:bg-gray-700' };
        }
    };

    if (!deployments || deployments.length === 0) {
        return (
            <div className="text-center py-12">
                <GitCommit className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                <p className="text-gray-500 dark:text-gray-400">No deployments yet</p>
            </div>
        );
    }

    return (
        <div className="flow-root">
            <ul className="-mb-8">
                {deployments.map((deployment, index) => {
                    const { Icon, color, bg } = getStatusIcon(deployment.status);
                    const isLast = index === deployments.length - 1;

                    return (
                        <li key={deployment.id}>
                            <div className="relative pb-8">
                                {/* Connector Line */}
                                {!isLast && (
                                    <span
                                        className="absolute top-5 left-5 -ml-px h-full w-0.5 bg-gray-200 dark:bg-gray-700"
                                        aria-hidden="true"
                                    />
                                )}

                                <div className="relative flex items-start space-x-3">
                                    {/* Icon */}
                                    <div className="relative">
                                        <div className={`flex items-center justify-center w-10 h-10 rounded-full ${bg} ${color}`}>
                                            <Icon className="w-5 h-5" />
                                            {deployment.status === 'running' && (
                                                <div className="absolute inset-0 rounded-full border-2 border-yellow-600 border-t-transparent animate-spin" />
                                            )}
                                        </div>
                                    </div>

                                    {/* Content */}
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center justify-between">
                                            <div className="flex-1">
                                                <p className="text-sm font-medium text-gray-900 dark:text-white">
                                                    {deployment.title || `Deployment #${deployment.id}`}
                                                </p>
                                                {deployment.description && (
                                                    <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                                                        {deployment.description}
                                                    </p>
                                                )}
                                            </div>
                                            <div className="flex-shrink-0 ml-4">
                                                <span className={`px-3 py-1 rounded-full text-xs font-medium ${
                                                    deployment.status === 'done'
                                                        ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                                                        : deployment.status === 'error'
                                                        ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                                                        : deployment.status === 'running'
                                                        ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                                                        : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
                                                }`}>
                                                    {deployment.status}
                                                </span>
                                            </div>
                                        </div>

                                        {/* Metadata */}
                                        <div className="mt-2 flex items-center gap-4 text-xs text-gray-500 dark:text-gray-400">
                                            <span title={format(new Date(deployment.created_at), 'PPpp')}>
                                                {formatDistanceToNow(new Date(deployment.created_at), { addSuffix: true })}
                                            </span>
                                            {deployment.version && (
                                                <>
                                                    <span>•</span>
                                                    <span>v{deployment.version}</span>
                                                </>
                                            )}
                                            {deployment.duration && (
                                                <>
                                                    <span>•</span>
                                                    <span>{deployment.duration}s</span>
                                                </>
                                            )}
                                            {deployment.commit_sha && (
                                                <>
                                                    <span>•</span>
                                                    <span className="font-mono">{deployment.commit_sha.substring(0, 7)}</span>
                                                </>
                                            )}
                                        </div>

                                        {/* Environment Badge */}
                                        {deployment.application?.environment && (
                                            <div className="mt-2">
                                                <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
                                                    {deployment.application.environment.toUpperCase()}
                                                </span>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            </div>
                        </li>
                    );
                })}
            </ul>
        </div>
    );
}
