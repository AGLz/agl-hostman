import React, { useState, useMemo } from 'react';
import { Head } from '@inertiajs/react';
import ProjectCard from '@/Components/Dokploy/ProjectCard';
import { Search, Grid, List, Filter } from 'lucide-react';

export default function DokployIndex({ projects, stats }) {
    const [viewMode, setViewMode] = useState('grid');
    const [searchQuery, setSearchQuery] = useState('');
    const [environmentFilter, setEnvironmentFilter] = useState('all');
    const [sortBy, setSortBy] = useState('recent');

    const filteredProjects = useMemo(() => {
        let filtered = projects;

        // Search filter
        if (searchQuery) {
            filtered = filtered.filter(project =>
                project.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                project.description?.toLowerCase().includes(searchQuery.toLowerCase())
            );
        }

        // Environment filter
        if (environmentFilter !== 'all') {
            filtered = filtered.filter(project =>
                project.applications?.some(app => app.environment === environmentFilter)
            );
        }

        // Sort
        switch (sortBy) {
            case 'recent':
                filtered = [...filtered].sort((a, b) =>
                    new Date(b.updated_at) - new Date(a.updated_at)
                );
                break;
            case 'name':
                filtered = [...filtered].sort((a, b) =>
                    a.name.localeCompare(b.name)
                );
                break;
            case 'status':
                filtered = [...filtered].sort((a, b) =>
                    (a.status || '').localeCompare(b.status || '')
                );
                break;
        }

        return filtered;
    }, [projects, searchQuery, environmentFilter, sortBy]);

    return (
        <>
            <Head title="Dokploy Dashboard" />

            <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
                {/* Header */}
                <div className="bg-white dark:bg-gray-800 shadow">
                    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                        <div className="flex items-center justify-between">
                            <div>
                                <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
                                    Dokploy Dashboard
                                </h1>
                                <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                                    Manage your deployments across all environments
                                </p>
                            </div>
                            <div className="flex items-center gap-4">
                                <a
                                    href="https://dok.aglz.io"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                                >
                                    Open Dokploy
                                </a>
                            </div>
                        </div>

                        {/* Stats */}
                        {stats && (
                            <div className="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
                                <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                    <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Total Projects</p>
                                    <p className="mt-1 text-3xl font-semibold text-gray-900 dark:text-white">
                                        {stats.total_projects || 0}
                                    </p>
                                </div>
                                <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                    <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Total Applications</p>
                                    <p className="mt-1 text-3xl font-semibold text-gray-900 dark:text-white">
                                        {stats.total_applications || 0}
                                    </p>
                                </div>
                                <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                    <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Active Deployments</p>
                                    <p className="mt-1 text-3xl font-semibold text-gray-900 dark:text-white">
                                        {stats.active_deployments || 0}
                                    </p>
                                </div>
                                <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                    <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Success Rate</p>
                                    <p className="mt-1 text-3xl font-semibold text-green-600 dark:text-green-400">
                                        {stats.success_rate || 0}%
                                    </p>
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* Filters and Controls */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                    <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-4">
                        <div className="flex flex-col md:flex-row gap-4 items-center justify-between">
                            {/* Search */}
                            <div className="relative flex-1 w-full md:w-auto">
                                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                                <input
                                    type="text"
                                    placeholder="Search projects..."
                                    value={searchQuery}
                                    onChange={(e) => setSearchQuery(e.target.value)}
                                    className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                />
                            </div>

                            {/* Environment Filter */}
                            <div className="flex items-center gap-2">
                                <Filter className="text-gray-400 w-5 h-5" />
                                <select
                                    value={environmentFilter}
                                    onChange={(e) => setEnvironmentFilter(e.target.value)}
                                    className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                                >
                                    <option value="all">All Environments</option>
                                    <option value="dev">Development</option>
                                    <option value="qa">QA</option>
                                    <option value="uat">UAT</option>
                                    <option value="prod">Production</option>
                                </select>
                            </div>

                            {/* Sort */}
                            <select
                                value={sortBy}
                                onChange={(e) => setSortBy(e.target.value)}
                                className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                            >
                                <option value="recent">Recent First</option>
                                <option value="name">Name (A-Z)</option>
                                <option value="status">Status</option>
                            </select>

                            {/* View Mode Toggle */}
                            <div className="flex rounded-lg overflow-hidden border border-gray-300 dark:border-gray-600">
                                <button
                                    onClick={() => setViewMode('grid')}
                                    className={`p-2 ${viewMode === 'grid' ? 'bg-blue-600 text-white' : 'bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-300'}`}
                                >
                                    <Grid className="w-5 h-5" />
                                </button>
                                <button
                                    onClick={() => setViewMode('list')}
                                    className={`p-2 ${viewMode === 'list' ? 'bg-blue-600 text-white' : 'bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-300'}`}
                                >
                                    <List className="w-5 h-5" />
                                </button>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Projects Grid/List */}
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-12">
                    {filteredProjects.length === 0 ? (
                        <div className="text-center py-12">
                            <p className="text-gray-500 dark:text-gray-400 text-lg">
                                No projects found
                            </p>
                        </div>
                    ) : (
                        <div className={
                            viewMode === 'grid'
                                ? 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'
                                : 'flex flex-col gap-4'
                        }>
                            {filteredProjects.map((project) => (
                                <ProjectCard
                                    key={project.id}
                                    project={project}
                                    viewMode={viewMode}
                                />
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </>
    );
}
