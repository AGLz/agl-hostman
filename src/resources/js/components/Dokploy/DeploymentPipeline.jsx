import React from 'react';
import { CheckCircle, XCircle, Clock, Circle, ArrowRight } from 'lucide-react';
import { format } from 'date-fns';

const environments = ['dev', 'qa', 'uat', 'prod'];

export default function DeploymentPipeline({ projectId, deployments }) {
    const getEnvironmentStatus = (env) => {
        const envDeployments = deployments.filter(d =>
            d.application?.environment === env
        );

        if (envDeployments.length === 0) {
            return {
                status: 'not_deployed',
                deployment: null,
                icon: Circle,
                color: 'text-gray-400',
                bgColor: 'bg-gray-100 dark:bg-gray-700',
            };
        }

        const latest = envDeployments[0];

        if (latest.status === 'running') {
            return {
                status: 'in_progress',
                deployment: latest,
                icon: Clock,
                color: 'text-yellow-600',
                bgColor: 'bg-yellow-100 dark:bg-yellow-900',
            };
        }

        if (latest.status === 'done') {
            return {
                status: 'success',
                deployment: latest,
                icon: CheckCircle,
                color: 'text-green-600',
                bgColor: 'bg-green-100 dark:bg-green-900',
            };
        }

        return {
            status: 'failed',
            deployment: latest,
            icon: XCircle,
            color: 'text-red-600',
            bgColor: 'bg-red-100 dark:bg-red-900',
        };
    };

    return (
        <div className="relative">
            {/* Pipeline */}
            <div className="flex items-center justify-between">
                {environments.map((env, index) => {
                    const status = getEnvironmentStatus(env);
                    const Icon = status.icon;

                    return (
                        <React.Fragment key={env}>
                            {/* Environment Stage */}
                            <div className="flex flex-col items-center flex-1">
                                {/* Circle with Icon */}
                                <div className={`relative flex items-center justify-center w-16 h-16 rounded-full ${status.bgColor} ${status.color}`}>
                                    <Icon className="w-8 h-8" />
                                    {status.status === 'in_progress' && (
                                        <div className="absolute inset-0 rounded-full border-4 border-yellow-600 border-t-transparent animate-spin" />
                                    )}
                                </div>

                                {/* Environment Name */}
                                <div className="mt-3 text-center">
                                    <p className="text-sm font-bold text-gray-900 dark:text-white uppercase">
                                        {env}
                                    </p>
                                    {status.deployment && (
                                        <>
                                            <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                                                {format(new Date(status.deployment.created_at), 'MMM dd, HH:mm')}
                                            </p>
                                            {status.deployment.version && (
                                                <p className="text-xs text-gray-400 dark:text-gray-500">
                                                    v{status.deployment.version}
                                                </p>
                                            )}
                                        </>
                                    )}
                                </div>

                                {/* Status Badge */}
                                <div className="mt-2">
                                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                                        status.status === 'success'
                                            ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                                            : status.status === 'failed'
                                            ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                                            : status.status === 'in_progress'
                                            ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                                            : 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400'
                                    }`}>
                                        {status.status.replace('_', ' ').toUpperCase()}
                                    </span>
                                </div>
                            </div>

                            {/* Arrow between stages */}
                            {index < environments.length - 1 && (
                                <div className="flex-shrink-0 mx-4">
                                    <ArrowRight className="w-6 h-6 text-gray-400" />
                                </div>
                            )}
                        </React.Fragment>
                    );
                })}
            </div>

            {/* Legend */}
            <div className="mt-8 pt-6 border-t border-gray-200 dark:border-gray-700">
                <div className="flex flex-wrap items-center justify-center gap-6 text-sm">
                    <div className="flex items-center gap-2">
                        <CheckCircle className="w-4 h-4 text-green-600" />
                        <span className="text-gray-600 dark:text-gray-400">Success</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <Clock className="w-4 h-4 text-yellow-600" />
                        <span className="text-gray-600 dark:text-gray-400">In Progress</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <XCircle className="w-4 h-4 text-red-600" />
                        <span className="text-gray-600 dark:text-gray-400">Failed</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <Circle className="w-4 h-4 text-gray-400" />
                        <span className="text-gray-600 dark:text-gray-400">Not Deployed</span>
                    </div>
                </div>
            </div>
        </div>
    );
}
