import React, { useEffect, useState } from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, Link } from '@inertiajs/react';
import { useArchon } from '@/hooks/useArchon';
import { useWebSocket } from '@/hooks/useWebSocket';

export default function Index({ auth, stats }) {
    const { isConnected } = useWebSocket({
        channels: ['archon'],
        events: {
            'archon.project.created': (data) => {
                console.log('Project created:', data);
            },
            'archon.task.created': (data) => {
                console.log('Task created:', data);
            }
        }
    });

    const [mcpStatus, setMcpStatus] = useState(stats.mcp_status || 'unknown');

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex justify-between items-center">
                    <h2 className="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
                        Archon AI Command Center
                    </h2>
                    <div className="flex items-center gap-4">
                        <span className={`px-3 py-1 rounded-full text-sm font-medium ${
                            isConnected ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' :
                            'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                        }`}>
                            {isConnected ? '● Live' : '○ Offline'}
                        </span>
                        <span className={`px-3 py-1 rounded-full text-sm font-medium ${
                            mcpStatus === 'connected' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                        }`}>
                            MCP: {mcpStatus}
                        </span>
                    </div>
                </div>
            }
        >
            <Head title="Archon Dashboard" />

            <div className="py-12">
                <div className="max-w-7xl mx-auto sm:px-6 lg:px-8">
                    {/* Stats Grid */}
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                        <StatCard
                            title="Total Projects"
                            value={stats.total_projects}
                            icon="📁"
                            color="blue"
                            link="/archon/projects"
                        />
                        <StatCard
                            title="Active Tasks"
                            value={stats.active_tasks}
                            icon="📋"
                            color="purple"
                            link="/archon/projects"
                        />
                        <StatCard
                            title="Knowledge Sources"
                            value={stats.knowledge_sources}
                            icon="📚"
                            color="green"
                            link="/archon/knowledge"
                        />
                        <StatCard
                            title="Documents"
                            value={stats.total_documents}
                            icon="📄"
                            color="yellow"
                            link="/archon/projects"
                        />
                    </div>

                    {/* Quick Actions */}
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                        <QuickAction
                            title="Knowledge Base"
                            description="Search AI-powered knowledge base with RAG"
                            icon="🔍"
                            link="/archon/knowledge"
                            color="blue"
                        />
                        <QuickAction
                            title="Manage Projects"
                            description="Create and track infrastructure projects"
                            icon="📊"
                            link="/archon/projects"
                            color="green"
                        />
                        <QuickAction
                            title="Task Board"
                            description="Kanban board for task management"
                            icon="📌"
                            link="/archon/projects"
                            color="purple"
                        />
                    </div>

                    {/* Recent Activity */}
                    <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                        <div className="p-6">
                            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                                Recent Activity
                            </h3>
                            <div className="space-y-3">
                                {stats.recent_tasks?.map((task, index) => (
                                    <div key={index} className="flex items-center justify-between py-2 border-b border-gray-200 dark:border-gray-700">
                                        <div>
                                            <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                                                {task.title}
                                            </p>
                                            <p className="text-xs text-gray-500 dark:text-gray-400">
                                                {task.project_name}
                                            </p>
                                        </div>
                                        <span className={`px-2 py-1 rounded text-xs font-medium ${
                                            task.status === 'done' ? 'bg-green-100 text-green-800' :
                                            task.status === 'doing' ? 'bg-blue-100 text-blue-800' :
                                            task.status === 'review' ? 'bg-yellow-100 text-yellow-800' :
                                            'bg-gray-100 text-gray-800'
                                        }`}>
                                            {task.status}
                                        </span>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>

                    {/* System Info */}
                    <div className="mt-6 bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                        <div className="p-6">
                            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                                System Information
                            </h3>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                                <div>
                                    <span className="font-medium text-gray-700 dark:text-gray-300">MCP Endpoint:</span>
                                    <span className="ml-2 text-gray-600 dark:text-gray-400">
                                        {stats.mcp_endpoint || 'http://10.6.0.21:8051/mcp'}
                                    </span>
                                </div>
                                <div>
                                    <span className="font-medium text-gray-700 dark:text-gray-300">Last Sync:</span>
                                    <span className="ml-2 text-gray-600 dark:text-gray-400">
                                        {stats.last_sync || 'Never'}
                                    </span>
                                </div>
                                <div>
                                    <span className="font-medium text-gray-700 dark:text-gray-300">WebSocket:</span>
                                    <span className="ml-2 text-gray-600 dark:text-gray-400">
                                        {isConnected ? 'Connected' : 'Disconnected'}
                                    </span>
                                </div>
                                <div>
                                    <span className="font-medium text-gray-700 dark:text-gray-300">Version:</span>
                                    <span className="ml-2 text-gray-600 dark:text-gray-400">
                                        v1.0.0
                                    </span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </AuthenticatedLayout>
    );
}

function StatCard({ title, value, icon, color, link }) {
    const colorClasses = {
        blue: 'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800',
        purple: 'bg-purple-50 dark:bg-purple-900/20 border-purple-200 dark:border-purple-800',
        green: 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800',
        yellow: 'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-800'
    };

    return (
        <Link href={link}>
            <div className={`p-6 rounded-lg border ${colorClasses[color]} hover:shadow-lg transition-shadow cursor-pointer`}>
                <div className="flex items-center justify-between mb-2">
                    <span className="text-2xl">{icon}</span>
                    <span className="text-3xl font-bold text-gray-900 dark:text-gray-100">
                        {value}
                    </span>
                </div>
                <h3 className="text-sm font-medium text-gray-600 dark:text-gray-400">
                    {title}
                </h3>
            </div>
        </Link>
    );
}

function QuickAction({ title, description, icon, link, color }) {
    const colorClasses = {
        blue: 'hover:bg-blue-50 dark:hover:bg-blue-900/20 border-blue-200 dark:border-blue-800',
        purple: 'hover:bg-purple-50 dark:hover:bg-purple-900/20 border-purple-200 dark:border-purple-800',
        green: 'hover:bg-green-50 dark:hover:bg-green-900/20 border-green-200 dark:border-green-800'
    };

    return (
        <Link href={link}>
            <div className={`p-6 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 ${colorClasses[color]} transition-colors cursor-pointer`}>
                <div className="text-4xl mb-3">{icon}</div>
                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                    {title}
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                    {description}
                </p>
            </div>
        </Link>
    );
}
