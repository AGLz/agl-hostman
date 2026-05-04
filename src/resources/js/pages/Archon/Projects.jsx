import React, { useState } from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, Link } from '@inertiajs/react';
import ProjectCard from '@/Components/Archon/ProjectCard';
import ProjectCreateModal from '@/Components/Archon/ProjectCreateModal';
import { useWebSocket } from '@/hooks/useWebSocket';

export default function Projects({ auth, projects = [], filters = {} }) {
    const [viewMode, setViewMode] = useState('grid');
    const [searchTerm, setSearchTerm] = useState('');
    const [sortBy, setSortBy] = useState('updated_at');
    const [showCreateModal, setShowCreateModal] = useState(false);
    const [localProjects, setLocalProjects] = useState(projects);

    useWebSocket({
        channels: ['archon'],
        events: {
            'archon.project.created': (data) => {
                setLocalProjects(prev => [data.project, ...prev]);
            },
            'archon.project.updated': (data) => {
                setLocalProjects(prev =>
                    prev.map(p => p.id === data.project.id ? data.project : p)
                );
            },
            'archon.project.deleted': (data) => {
                setLocalProjects(prev =>
                    prev.filter(p => p.id !== data.project_id)
                );
            }
        }
    });

    const filteredProjects = localProjects
        .filter(project =>
            project.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
            project.description?.toLowerCase().includes(searchTerm.toLowerCase())
        )
        .sort((a, b) => {
            if (sortBy === 'title') return a.title.localeCompare(b.title);
            if (sortBy === 'created_at') return new Date(b.created_at) - new Date(a.created_at);
            return new Date(b.updated_at) - new Date(a.updated_at);
        });

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex justify-between items-center">
                    <h2 className="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
                        Projects
                    </h2>
                    <button
                        onClick={() => setShowCreateModal(true)}
                        className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                    >
                        + New Project
                    </button>
                </div>
            }
        >
            <Head title="Projects" />

            <div className="py-12">
                <div className="max-w-7xl mx-auto sm:px-6 lg:px-8">
                    {/* Controls */}
                    <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg mb-6">
                        <div className="p-6">
                            <div className="flex flex-wrap gap-4 items-center justify-between">
                                <div className="flex-1 min-w-64">
                                    <input
                                        type="text"
                                        placeholder="Search projects..."
                                        value={searchTerm}
                                        onChange={(e) => setSearchTerm(e.target.value)}
                                        className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                    />
                                </div>

                                <div className="flex gap-2">
                                    <select
                                        value={sortBy}
                                        onChange={(e) => setSortBy(e.target.value)}
                                        className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                    >
                                        <option value="updated_at">Last Updated</option>
                                        <option value="created_at">Created Date</option>
                                        <option value="title">Title</option>
                                    </select>

                                    <div className="flex rounded-md shadow-sm">
                                        <button
                                            onClick={() => setViewMode('grid')}
                                            className={`px-4 py-2 border ${
                                                viewMode === 'grid'
                                                    ? 'bg-blue-600 text-white border-blue-600'
                                                    : 'bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 border-gray-300 dark:border-gray-600'
                                            } rounded-l-md`}
                                        >
                                            Grid
                                        </button>
                                        <button
                                            onClick={() => setViewMode('list')}
                                            className={`px-4 py-2 border ${
                                                viewMode === 'list'
                                                    ? 'bg-blue-600 text-white border-blue-600'
                                                    : 'bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 border-gray-300 dark:border-gray-600'
                                            } rounded-r-md border-l-0`}
                                        >
                                            List
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Projects */}
                    {filteredProjects.length > 0 ? (
                        <div className={
                            viewMode === 'grid'
                                ? 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'
                                : 'space-y-4'
                        }>
                            {filteredProjects.map(project => (
                                <ProjectCard
                                    key={project.id}
                                    project={project}
                                    viewMode={viewMode}
                                />
                            ))}
                        </div>
                    ) : (
                        <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                            <div className="p-12 text-center">
                                <div className="text-6xl mb-4">📁</div>
                                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                                    {searchTerm ? 'No projects found' : 'No projects yet'}
                                </h3>
                                <p className="text-gray-600 dark:text-gray-400 mb-4">
                                    {searchTerm
                                        ? 'Try adjusting your search'
                                        : 'Create your first project to get started'
                                    }
                                </p>
                                {!searchTerm && (
                                    <button
                                        onClick={() => setShowCreateModal(true)}
                                        className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                                    >
                                        + Create Project
                                    </button>
                                )}
                            </div>
                        </div>
                    )}
                </div>
            </div>

            {showCreateModal && (
                <ProjectCreateModal
                    onClose={() => setShowCreateModal(false)}
                />
            )}
        </AuthenticatedLayout>
    );
}
