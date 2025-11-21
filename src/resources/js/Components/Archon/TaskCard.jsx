import React, { useState } from 'react';
import { router } from '@inertiajs/react';

export default function TaskCard({ task, projectId, viewMode = 'kanban', isDragging = false }) {
    const [isEditing, setIsEditing] = useState(false);
    const [editedTask, setEditedTask] = useState(task);

    const priorityColors = {
        high: 'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-200 border-red-300 dark:border-red-700',
        medium: 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-200 border-yellow-300 dark:border-yellow-700',
        low: 'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200 border-gray-300 dark:border-gray-600'
    };

    const statusColors = {
        todo: 'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200',
        doing: 'bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-200',
        review: 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-200',
        done: 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-200'
    };

    const handleUpdate = () => {
        router.put(route('archon.tasks.update', task.id), editedTask, {
            onSuccess: () => setIsEditing(false)
        });
    };

    const handleDelete = () => {
        if (confirm('Are you sure you want to delete this task?')) {
            router.delete(route('archon.tasks.destroy', task.id));
        }
    };

    const handleStatusChange = (newStatus) => {
        router.put(route('archon.tasks.update', task.id), {
            ...task,
            status: newStatus
        });
    };

    if (viewMode === 'kanban') {
        return (
            <div
                className={`bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 p-4 cursor-move hover:shadow-md transition-shadow ${
                    isDragging ? 'opacity-50' : ''
                }`}
            >
                <div className="flex justify-between items-start mb-2">
                    <h4 className="font-medium text-gray-900 dark:text-gray-100 line-clamp-2">
                        {task.title}
                    </h4>
                    {task.task_order && (
                        <span className="text-xs text-gray-400 ml-2">
                            #{task.task_order}
                        </span>
                    )}
                </div>

                {task.description && (
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-3 line-clamp-3">
                        {task.description}
                    </p>
                )}

                <div className="flex flex-wrap gap-2 mb-3">
                    {task.feature && (
                        <span className="px-2 py-1 bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-200 rounded text-xs">
                            {task.feature}
                        </span>
                    )}
                    {task.priority && (
                        <span className={`px-2 py-1 rounded text-xs border ${priorityColors[task.priority] || priorityColors.low}`}>
                            {task.priority}
                        </span>
                    )}
                </div>

                {task.assignee && (
                    <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                        <span>👤</span>
                        <span>{task.assignee}</span>
                    </div>
                )}

                <button
                    onClick={handleDelete}
                    className="mt-3 text-xs text-red-600 hover:text-red-800 dark:text-red-400"
                >
                    Delete
                </button>
            </div>
        );
    }

    // List view
    return (
        <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
            <div className="p-6">
                <div className="flex justify-between items-start">
                    <div className="flex-1">
                        <div className="flex items-center gap-3 mb-2">
                            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                                {task.title}
                            </h3>
                            <span className={`px-2 py-1 rounded text-xs ${statusColors[task.status]}`}>
                                {task.status}
                            </span>
                            {task.priority && (
                                <span className={`px-2 py-1 rounded text-xs border ${priorityColors[task.priority]}`}>
                                    {task.priority}
                                </span>
                            )}
                        </div>

                        {task.description && (
                            <p className="text-gray-600 dark:text-gray-400 mb-3">
                                {task.description}
                            </p>
                        )}

                        <div className="flex flex-wrap gap-4 text-sm">
                            {task.assignee && (
                                <span className="text-gray-600 dark:text-gray-400">
                                    👤 {task.assignee}
                                </span>
                            )}
                            {task.feature && (
                                <span className="px-2 py-1 bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-200 rounded text-xs">
                                    {task.feature}
                                </span>
                            )}
                            <span className="text-gray-500 dark:text-gray-400">
                                Updated {new Date(task.updated_at).toLocaleDateString()}
                            </span>
                        </div>
                    </div>

                    <div className="flex gap-2 ml-4">
                        {task.status !== 'done' && (
                            <select
                                value={task.status}
                                onChange={(e) => handleStatusChange(e.target.value)}
                                className="px-3 py-1 border border-gray-300 dark:border-gray-600 rounded text-sm dark:bg-gray-700 dark:text-gray-200"
                            >
                                <option value="todo">Todo</option>
                                <option value="doing">Doing</option>
                                <option value="review">Review</option>
                                <option value="done">Done</option>
                            </select>
                        )}
                        <button
                            onClick={handleDelete}
                            className="px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 text-sm"
                        >
                            Delete
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
