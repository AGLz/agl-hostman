import { useState, useMemo } from 'react';
import { router } from '@inertiajs/react';

/**
 * Custom hook for Kanban drag-drop logic
 *
 * @param {Object} options - Configuration options
 * @param {Array} options.tasks - Array of tasks
 * @param {string} options.projectId - Project ID
 * @param {Function} options.onTaskUpdate - Callback when task is updated
 * @returns {Object} - { tasksByStatus, activeTask, handleDragStart, handleDragOver, handleDragEnd }
 */
export function useTaskDragDrop({ tasks, projectId, onTaskUpdate }) {
    const [activeTask, setActiveTask] = useState(null);

    // Group tasks by status
    const tasksByStatus = useMemo(() => {
        return {
            todo: tasks.filter(t => t.status === 'todo'),
            doing: tasks.filter(t => t.status === 'doing'),
            review: tasks.filter(t => t.status === 'review'),
            done: tasks.filter(t => t.status === 'done')
        };
    }, [tasks]);

    const handleDragStart = (event) => {
        const { active } = event;
        const task = tasks.find(t => t.id === active.id);
        setActiveTask(task);
    };

    const handleDragOver = (event) => {
        const { active, over } = event;

        if (!over) return;

        const activeId = active.id;
        const overId = over.id;

        if (activeId === overId) return;

        // Find the status of the container we're over
        const activeTask = tasks.find(t => t.id === activeId);
        const overTask = tasks.find(t => t.id === overId);

        if (!activeTask) return;

        // If we're over a task, use that task's status
        if (overTask && activeTask.status !== overTask.status) {
            // Optimistically update the local state
            if (onTaskUpdate) {
                onTaskUpdate({
                    ...activeTask,
                    status: overTask.status
                });
            }
        }
    };

    const handleDragEnd = (event) => {
        const { active, over } = event;

        setActiveTask(null);

        if (!over) return;

        const activeId = active.id;
        const overId = over.id;

        if (activeId === overId) return;

        const activeTask = tasks.find(t => t.id === activeId);
        const overTask = tasks.find(t => t.id === overId);

        if (!activeTask) return;

        let newStatus = activeTask.status;

        // Determine new status based on where the task was dropped
        if (overTask) {
            newStatus = overTask.status;
        } else {
            // If dropped on a column (not a task), parse the status from the container ID
            // This assumes container IDs follow a pattern like "column-todo", "column-doing", etc.
            const statusMatch = overId.match(/column-(\w+)/);
            if (statusMatch) {
                newStatus = statusMatch[1];
            }
        }

        // Only update if status changed
        if (newStatus !== activeTask.status) {
            // Send update to server
            router.put(
                route('archon.tasks.update', activeTask.id),
                {
                    ...activeTask,
                    status: newStatus
                },
                {
                    preserveScroll: true,
                    onSuccess: () => {
                        if (onTaskUpdate) {
                            onTaskUpdate({
                                ...activeTask,
                                status: newStatus
                            });
                        }
                    },
                    onError: (errors) => {
                        console.error('Task update failed:', errors);
                    }
                }
            );
        }
    };

    return {
        tasksByStatus,
        activeTask,
        handleDragStart,
        handleDragOver,
        handleDragEnd
    };
}
