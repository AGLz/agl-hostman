import React from 'react';
import { Link, router } from '@inertiajs/react';

export default function ProjectCard({ project, viewMode = 'grid' }) {
    const handleDelete = (e) => {
        e.preventDefault();
        if (confirm('Are you sure you want to delete this project?')) {
            router.delete(route('archon.projects.destroy', project.id));
        }
    };

    const taskStats = {
        total: project.tasks_count || 0,
        todo: project.tasks_todo_count || 0,
        doing: project.tasks_doing_count || 0,
        review: project.tasks_review_count || 0,
        done: project.tasks_done_count || 0
    };

    if (viewMode === 'list') {
        return (
            <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg hover:shadow-lg transition-shadow">
                <div className="p-6">
                    <div className="flex justify-between items-start">
                        <div className="flex-1">
                            <Link
                                href={route('archon.projects.show', project.id)}
                                className="text-xl font-semibold text-gray-900 dark:text-gray-100 hover:text-blue-600 dark:hover:text-blue-400"
                            >
                                {project.title}
                            </Link>
                            {project.description && (
                                <p className="mt-2 text-gray-600 dark:text-gray-400">
                                    {project.description}
                                </p>
                            )}
                            <div className="mt-4 flex gap-4 text-sm">
                                <span className="text-gray-500 dark:text-gray-400">
                                    Tasks: {taskStats.total}
                                </span>
                                {project.github_repo && (
                                    <a
                                        href={project.github_repo}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="text-blue-600 hover:text-blue-800 dark:text-blue-400"
                                    >
                                        🔗 GitHub
                                    </a>
                                )}
                                <span className="text-gray-500 dark:text-gray-400">
                                    Updated {new Date(project.updated_at).toLocaleDateString()}
                                </span>
                            </div>
                        </div>
                        <div className="flex gap-2 ml-4">
                            <Link
                                href={route('archon.projects.show', project.id)}
                                className="px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm"
                            >
                                View
                            </Link>
                            <button
                                onClick={handleDelete}
                                className="px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 text-sm"
                            >
                                Delete
                            </button>
                        </div>
                    </div>

                    {taskStats.total > 0 && (
                        <div className="mt-4 flex gap-2">
                            {taskStats.todo > 0 && (
                                <span className="px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200 rounded text-xs">
                                    Todo: {taskStats.todo}
                                </span>
                            )}
                            {taskStats.doing > 0 && (
                                <span className="px-2 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-200 rounded text-xs">
                                    Doing: {taskStats.doing}
                                </span>
                            )}
                            {taskStats.review > 0 && (
                                <span className="px-2 py-1 bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-200 rounded text-xs">
                                    Review: {taskStats.review}
                                </span>
                            )}
                            {taskStats.done > 0 && (
                                <span className="px-2 py-1 bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-200 rounded text-xs">
                                    Done: {taskStats.done}
                                </span>
                            )}
                        </div>
                    )}
                </div>
            </div>
        );
    }

    // Grid mode
    return (
        <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg hover:shadow-lg transition-shadow">
            <div className="p-6">
                <Link
                    href={route('archon.projects.show', project.id)}
                    className="text-xl font-semibold text-gray-900 dark:text-gray-100 hover:text-blue-600 dark:hover:text-blue-400"
                >
                    {project.title}
                </Link>

                {project.description && (
                    <p className="mt-2 text-gray-600 dark:text-gray-400 line-clamp-2">
                        {project.description}
                    </p>
                )}

                <div className="mt-4">
                    <div className="text-3xl font-bold text-gray-900 dark:text-gray-100">
                        {taskStats.total}
                    </div>
                    <div className="text-sm text-gray-500 dark:text-gray-400">
                        Total Tasks
                    </div>
                </div>

                {taskStats.total > 0 && (
                    <div className="mt-4 space-y-2">
                        <div className="flex justify-between text-sm">
                            <span className="text-gray-600 dark:text-gray-400">Progress</span>
                            <span className="text-gray-900 dark:text-gray-100 font-medium">
                                {Math.round((taskStats.done / taskStats.total) * 100)}%
                            </span>
                        </div>
                        <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                            <div
                                className="bg-green-600 h-2 rounded-full transition-all"
                                style={{
                                    width: `${(taskStats.done / taskStats.total) * 100}%`
                                }}
                            />
                        </div>
                    </div>
                )}

                <div className="mt-4 flex gap-2 text-xs">
                    {taskStats.todo > 0 && (
                        <span className="px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200 rounded">
                            {taskStats.todo} todo
                        </span>
                    )}
                    {taskStats.doing > 0 && (
                        <span className="px-2 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-200 rounded">
                            {taskStats.doing} doing
                        </span>
                    )}
                    {taskStats.done > 0 && (
                        <span className="px-2 py-1 bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-200 rounded">
                            {taskStats.done} done
                        </span>
                    )}
                </div>

                <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700 flex justify-between items-center">
                    <span className="text-xs text-gray-500 dark:text-gray-400">
                        {new Date(project.updated_at).toLocaleDateString()}
                    </span>
                    <div className="flex gap-2">
                        <Link
                            href={route('archon.projects.show', project.id)}
                            className="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400"
                        >
                            View →
                        </Link>
                    </div>
                </div>
            </div>
        </div>
    );
}
