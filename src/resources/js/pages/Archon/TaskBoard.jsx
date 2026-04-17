import React, { useState } from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, Link } from '@inertiajs/react';
import KanbanBoard from '@/Components/Archon/KanbanBoard';
import TaskCreateModal from '@/Components/Archon/TaskCreateModal';
import { useWebSocket } from '@/hooks/useWebSocket';

export default function TaskBoard({ auth, project, tasks = [] }) {
    const [showCreateModal, setShowCreateModal] = useState(false);
    const [localTasks, setLocalTasks] = useState(tasks);
    const [filterAssignee, setFilterAssignee] = useState('all');
    const [filterFeature, setFilterFeature] = useState('all');
    const [searchTerm, setSearchTerm] = useState('');

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
            'archon.task.moved': (data) => {
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
        if (filterAssignee !== 'all' && task.assignee !== filterAssignee) return false;
        if (filterFeature !== 'all' && task.feature !== filterFeature) return false;
        if (searchTerm && !task.title.toLowerCase().includes(searchTerm.toLowerCase())) return false;
        return true;
    });

    const uniqueAssignees = [...new Set(localTasks.map(t => t.assignee).filter(Boolean))];
    const uniqueFeatures = [...new Set(localTasks.map(t => t.feature).filter(Boolean))];

    const handleTaskUpdate = (updatedTask) => {
        setLocalTasks(prev =>
            prev.map(t => t.id === updatedTask.id ? updatedTask : t)
        );
    };

    const handleArchiveCompleted = () => {
        if (confirm('Archive all completed tasks?')) {
            const completedTasks = localTasks.filter(t => t.status === 'done');
            // Here you would call the API to archive tasks
            console.log('Archiving tasks:', completedTasks);
        }
    };

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex justify-between items-center">
                    <div>
                        <Link
                            href={route('archon.projects.show', project.id)}
                            className="text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200 mb-2 inline-block"
                        >
                            ← Back to Project
                        </Link>
                        <h2 className="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
                            {project.title} - Task Board
                        </h2>
                    </div>
                    <div className="flex gap-2">
                        <button
                            onClick={() => setShowCreateModal(true)}
                            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                        >
                            + New Task
                        </button>
                        <button
                            onClick={handleArchiveCompleted}
                            className="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 transition-colors"
                        >
                            Archive Completed
                        </button>
                    </div>
                </div>
            }
        >
            <Head title={`${project.title} - Task Board`} />

            <div className="py-12">
                <div className="max-w-full mx-auto sm:px-6 lg:px-8">
                    {/* Filters */}
                    <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg mb-6">
                        <div className="p-6">
                            <div className="flex flex-wrap gap-4">
                                <div className="flex-1 min-w-64">
                                    <input
                                        type="text"
                                        placeholder="Search tasks..."
                                        value={searchTerm}
                                        onChange={(e) => setSearchTerm(e.target.value)}
                                        className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                    />
                                </div>

                                {uniqueAssignees.length > 0 && (
                                    <div>
                                        <select
                                            value={filterAssignee}
                                            onChange={(e) => setFilterAssignee(e.target.value)}
                                            className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                        >
                                            <option value="all">All Assignees</option>
                                            {uniqueAssignees.map(assignee => (
                                                <option key={assignee} value={assignee}>
                                                    {assignee}
                                                </option>
                                            ))}
                                        </select>
                                    </div>
                                )}

                                {uniqueFeatures.length > 0 && (
                                    <div>
                                        <select
                                            value={filterFeature}
                                            onChange={(e) => setFilterFeature(e.target.value)}
                                            className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                        >
                                            <option value="all">All Features</option>
                                            {uniqueFeatures.map(feature => (
                                                <option key={feature} value={feature}>
                                                    {feature}
                                                </option>
                                            ))}
                                        </select>
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Kanban Board */}
                    <KanbanBoard
                        tasks={filteredTasks}
                        projectId={project.id}
                        onTaskUpdate={handleTaskUpdate}
                    />
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
