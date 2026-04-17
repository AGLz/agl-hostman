import React, { useState } from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, Link, router } from '@inertiajs/react';
import TaskCard from '@/Components/Archon/TaskCard';
import TaskCreateModal from '@/Components/Archon/TaskCreateModal';
import { useWebSocket } from '@/hooks/useWebSocket';

export default function ProjectShow({ auth, project, tasks = [] }) {
    const [showCreateModal, setShowCreateModal] = useState(false);
    const [localTasks, setLocalTasks] = useState(tasks);
    const [filterStatus, setFilterStatus] = useState('all');
    const [filterAssignee, setFilterAssignee] = useState('all');

    useWebSocket({
        channels: [`archon.projects.${project.id}`],
        events: {
            'archon.task.created': (data) => {
                if (data.task.project_id === project.id) {
                    setLocalTasks(prev => [...prev, data.task]);
                }
            },
            'archon.task.updated': (data) => {
                if (data.task.project_id === project.id) {
                    setLocalTasks(prev =>
                        prev.map(t => t.id === data.task.id ? data.task : t)
                    );
                }
            },
            'archon.task.deleted': (data) => {
                setLocalTasks(prev =>
                    prev.filter(t => t.id !== data.task_id)
                );
            }
        }
    });

    const filteredTasks = localTasks.filter(task => {
        if (filterStatus !== 'all' && task.status !== filterStatus) return false;
        if (filterAssignee !== 'all' && task.assignee !== filterAssignee) return false;
        return true;
    });

    const tasksByStatus = {
        todo: filteredTasks.filter(t => t.status === 'todo'),
        doing: filteredTasks.filter(t => t.status === 'doing'),
        review: filteredTasks.filter(t => t.status === 'review'),
        done: filteredTasks.filter(t => t.status === 'done')
    };

    const uniqueAssignees = [...new Set(localTasks.map(t => t.assignee).filter(Boolean))];

    const handleDeleteProject = () => {
        if (confirm('Are you sure you want to delete this project? All tasks will be deleted.')) {
            router.delete(route('archon.projects.destroy', project.id));
        }
    };

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex justify-between items-center">
                    <div>
                        <Link
                            href="/archon/projects"
                            className="text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200 mb-2 inline-block"
                        >
                            ← Back to Projects
                        </Link>
                        <h2 className="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
                            {project.title}
                        </h2>
                    </div>
                    <div className="flex gap-2">
                        <button
                            onClick={() => setShowCreateModal(true)}
                            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                        >
                            + New Task
                        </button>
                        <Link
                            href={route('archon.projects.tasks.board', project.id)}
                            className="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 transition-colors"
                        >
                            Kanban Board
                        </Link>
                        <button
                            onClick={handleDeleteProject}
                            className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
                        >
                            Delete Project
                        </button>
                    </div>
                </div>
            }
        >
            <Head title={project.title} />

            <div className="py-12">
                <div className="max-w-7xl mx-auto sm:px-6 lg:px-8">
                    {/* Project Info */}
                    <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg mb-6">
                        <div className="p-6">
                            {project.description && (
                                <p className="text-gray-600 dark:text-gray-400 mb-4">
                                    {project.description}
                                </p>
                            )}
                            <div className="flex flex-wrap gap-4 text-sm">
                                {project.github_repo && (
                                    <a
                                        href={project.github_repo}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
                                    >
                                        🔗 GitHub Repository
                                    </a>
                                )}
                                <span className="text-gray-600 dark:text-gray-400">
                                    Created: {new Date(project.created_at).toLocaleDateString()}
                                </span>
                                <span className="text-gray-600 dark:text-gray-400">
                                    Updated: {new Date(project.updated_at).toLocaleDateString()}
                                </span>
                            </div>
                        </div>
                    </div>

                    {/* Filters */}
                    <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg mb-6">
                        <div className="p-6">
                            <div className="flex gap-4">
                                <div>
                                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300 mr-2">
                                        Status:
                                    </label>
                                    <select
                                        value={filterStatus}
                                        onChange={(e) => setFilterStatus(e.target.value)}
                                        className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                    >
                                        <option value="all">All</option>
                                        <option value="todo">Todo</option>
                                        <option value="doing">Doing</option>
                                        <option value="review">Review</option>
                                        <option value="done">Done</option>
                                    </select>
                                </div>
                                <div>
                                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300 mr-2">
                                        Assignee:
                                    </label>
                                    <select
                                        value={filterAssignee}
                                        onChange={(e) => setFilterAssignee(e.target.value)}
                                        className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                    >
                                        <option value="all">All</option>
                                        {uniqueAssignees.map(assignee => (
                                            <option key={assignee} value={assignee}>
                                                {assignee}
                                            </option>
                                        ))}
                                    </select>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Task Stats */}
                    <div className="grid grid-cols-4 gap-4 mb-6">
                        {Object.entries(tasksByStatus).map(([status, tasks]) => (
                            <div
                                key={status}
                                className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-6"
                            >
                                <div className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                                    {tasks.length}
                                </div>
                                <div className="text-sm text-gray-600 dark:text-gray-400 capitalize">
                                    {status}
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* Tasks List */}
                    {filteredTasks.length > 0 ? (
                        <div className="space-y-4">
                            {filteredTasks.map(task => (
                                <TaskCard
                                    key={task.id}
                                    task={task}
                                    projectId={project.id}
                                    viewMode="list"
                                />
                            ))}
                        </div>
                    ) : (
                        <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                            <div className="p-12 text-center">
                                <div className="text-6xl mb-4">📋</div>
                                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                                    No tasks yet
                                </h3>
                                <p className="text-gray-600 dark:text-gray-400 mb-4">
                                    Create your first task to get started
                                </p>
                                <button
                                    onClick={() => setShowCreateModal(true)}
                                    className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                                >
                                    + Create Task
                                </button>
                            </div>
                        </div>
                    )}
                </div>
            </div>

            {showCreateModal && (
                <TaskCreateModal
                    projectId={project.id}
                    onClose={() => setShowCreateModal(false)}
                />
            )}
        </AuthenticatedLayout>
    );
}
