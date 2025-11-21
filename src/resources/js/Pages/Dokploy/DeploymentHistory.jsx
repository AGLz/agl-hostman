import React, { useState, useMemo } from 'react';
import { Head, Link } from '@inertiajs/react';
import DeploymentTimeline from '@/Components/Dokploy/DeploymentTimeline';
import EnvironmentBadge from '@/Components/Dokploy/EnvironmentBadge';
import { ChevronLeft, Filter, Calendar, Download } from 'lucide-react';
import { format } from 'date-fns';

export default function DeploymentHistory({ deployments, filters }) {
    const [environmentFilter, setEnvironmentFilter] = useState(filters?.environment || 'all');
    const [statusFilter, setStatusFilter] = useState(filters?.status || 'all');
    const [dateRange, setDateRange] = useState(filters?.dateRange || 'all');

    const filteredDeployments = useMemo(() => {
        let filtered = deployments;

        // Environment filter
        if (environmentFilter !== 'all') {
            filtered = filtered.filter(d => d.application?.environment === environmentFilter);
        }

        // Status filter
        if (statusFilter !== 'all') {
            filtered = filtered.filter(d => d.status === statusFilter);
        }

        // Date range filter
        if (dateRange !== 'all') {
            const now = new Date();
            const ranges = {
                '24h': new Date(now.getTime() - 24 * 60 * 60 * 1000),
                '7d': new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000),
                '30d': new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000),
            };

            if (ranges[dateRange]) {
                filtered = filtered.filter(d => new Date(d.created_at) >= ranges[dateRange]);
            }
        }

        return filtered;
    }, [deployments, environmentFilter, statusFilter, dateRange]);

    const exportDeployments = () => {
        const csv = [
            ['Date', 'Application', 'Environment', 'Status', 'Duration'],
            ...filteredDeployments.map(d => [
                format(new Date(d.created_at), 'yyyy-MM-dd HH:mm:ss'),
                d.application?.name || 'Unknown',
                d.application?.environment || 'Unknown',
                d.status || 'Unknown',
                d.duration || 'N/A',
            ]),
        ].map(row => row.join(',')).join('\n');

        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `deployment-history-${format(new Date(), 'yyyy-MM-dd')}.csv`;
        a.click();
    };

    const stats = useMemo(() => {
        const total = filteredDeployments.length;
        const successful = filteredDeployments.filter(d => d.status === 'done').length;
        const failed = filteredDeployments.filter(d => d.status === 'error').length;
        const inProgress = filteredDeployments.filter(d => d.status === 'running').length;

        return {
            total,
            successful,
            failed,
            inProgress,
            successRate: total > 0 ? Math.round((successful / total) * 100) : 0,
        };
    }, [filteredDeployments]);

    return (
        <>
            <Head title="Deployment History" />

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
                                    Deployment History
                                </h1>
                                <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                                    View and analyze all deployments across environments
                                </p>
                            </div>
                            <button
                                onClick={exportDeployments}
                                className="flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition"
                            >
                                <Download className="w-5 h-5" />
                                Export CSV
                            </button>
                        </div>

                        {/* Stats */}
                        <div className="mt-6 grid grid-cols-1 md:grid-cols-5 gap-4">
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Total</p>
                                <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                                    {stats.total}
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Successful</p>
                                <p className="mt-1 text-2xl font-semibold text-green-600">
                                    {stats.successful}
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Failed</p>
                                <p className="mt-1 text-2xl font-semibold text-red-600">
                                    {stats.failed}
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">In Progress</p>
                                <p className="mt-1 text-2xl font-semibold text-yellow-600">
                                    {stats.inProgress}
                                </p>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Success Rate</p>
                                <p className="mt-1 text-2xl font-semibold text-blue-600">
                                    {stats.successRate}%
                                </p>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Filters */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                    <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-4">
                        <div className="flex flex-col md:flex-row gap-4 items-center">
                            <Filter className="text-gray-400 w-5 h-5" />

                            <select
                                value={environmentFilter}
                                onChange={(e) => setEnvironmentFilter(e.target.value)}
                                className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                            >
                                <option value="all">All Environments</option>
                                <option value="dev">Development</option>
                                <option value="qa">QA</option>
                                <option value="uat">UAT</option>
                                <option value="prod">Production</option>
                            </select>

                            <select
                                value={statusFilter}
                                onChange={(e) => setStatusFilter(e.target.value)}
                                className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                            >
                                <option value="all">All Statuses</option>
                                <option value="done">Successful</option>
                                <option value="error">Failed</option>
                                <option value="running">In Progress</option>
                                <option value="idle">Idle</option>
                            </select>

                            <select
                                value={dateRange}
                                onChange={(e) => setDateRange(e.target.value)}
                                className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                            >
                                <option value="all">All Time</option>
                                <option value="24h">Last 24 Hours</option>
                                <option value="7d">Last 7 Days</option>
                                <option value="30d">Last 30 Days</option>
                            </select>
                        </div>
                    </div>
                </div>

                {/* Timeline */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-12">
                    <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                        {filteredDeployments.length === 0 ? (
                            <div className="text-center py-12">
                                <Calendar className="mx-auto w-12 h-12 text-gray-400 mb-4" />
                                <p className="text-gray-500 dark:text-gray-400 text-lg">
                                    No deployments found matching the selected filters
                                </p>
                            </div>
                        ) : (
                            <DeploymentTimeline deployments={filteredDeployments} />
                        )}
                    </div>
                </div>
            </div>
        </>
    );
}
