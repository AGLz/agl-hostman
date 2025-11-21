import React from 'react';
import {
    DndContext,
    DragOverlay,
    closestCorners,
    KeyboardSensor,
    PointerSensor,
    useSensor,
    useSensors,
} from '@dnd-kit/core';
import {
    arrayMove,
    SortableContext,
    sortableKeyboardCoordinates,
    verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { router } from '@inertiajs/react';
import TaskCard from './TaskCard';
import { useTaskDragDrop } from '@/hooks/useTaskDragDrop';

function SortableTask({ task, projectId }) {
    const {
        attributes,
        listeners,
        setNodeRef,
        transform,
        transition,
        isDragging,
    } = useSortable({ id: task.id });

    const style = {
        transform: CSS.Transform.toString(transform),
        transition,
    };

    return (
        <div ref={setNodeRef} style={style} {...attributes} {...listeners}>
            <TaskCard task={task} projectId={projectId} viewMode="kanban" isDragging={isDragging} />
        </div>
    );
}

function KanbanColumn({ status, tasks, projectId, title, color }) {
    const colorClasses = {
        gray: 'bg-gray-50 dark:bg-gray-900/50 border-gray-200 dark:border-gray-700',
        blue: 'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-700',
        yellow: 'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-700',
        green: 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-700'
    };

    return (
        <div className="flex-1 min-w-80">
            <div className={`rounded-lg border ${colorClasses[color]} p-4`}>
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-semibold text-gray-900 dark:text-gray-100">
                        {title}
                    </h3>
                    <span className="px-2 py-1 bg-white dark:bg-gray-800 rounded text-sm font-medium">
                        {tasks.length}
                    </span>
                </div>

                <SortableContext
                    items={tasks.map(t => t.id)}
                    strategy={verticalListSortingStrategy}
                >
                    <div className="space-y-3 min-h-32">
                        {tasks.map(task => (
                            <SortableTask key={task.id} task={task} projectId={projectId} />
                        ))}
                    </div>
                </SortableContext>

                {tasks.length === 0 && (
                    <div className="text-center py-8 text-gray-400 dark:text-gray-500 text-sm">
                        No tasks
                    </div>
                )}
            </div>
        </div>
    );
}

export default function KanbanBoard({ tasks, projectId, onTaskUpdate }) {
    const {
        tasksByStatus,
        activeTask,
        handleDragStart,
        handleDragOver,
        handleDragEnd,
    } = useTaskDragDrop({
        tasks,
        projectId,
        onTaskUpdate
    });

    const sensors = useSensors(
        useSensor(PointerSensor),
        useSensor(KeyboardSensor, {
            coordinateGetter: sortableKeyboardCoordinates,
        })
    );

    return (
        <DndContext
            sensors={sensors}
            collisionDetection={closestCorners}
            onDragStart={handleDragStart}
            onDragOver={handleDragOver}
            onDragEnd={handleDragEnd}
        >
            <div className="flex gap-4 overflow-x-auto pb-4">
                <KanbanColumn
                    status="todo"
                    tasks={tasksByStatus.todo}
                    projectId={projectId}
                    title="📋 Todo"
                    color="gray"
                />
                <KanbanColumn
                    status="doing"
                    tasks={tasksByStatus.doing}
                    projectId={projectId}
                    title="🔄 Doing"
                    color="blue"
                />
                <KanbanColumn
                    status="review"
                    tasks={tasksByStatus.review}
                    projectId={projectId}
                    title="👀 Review"
                    color="yellow"
                />
                <KanbanColumn
                    status="done"
                    tasks={tasksByStatus.done}
                    projectId={projectId}
                    title="✅ Done"
                    color="green"
                />
            </div>

            <DragOverlay>
                {activeTask ? (
                    <TaskCard task={activeTask} projectId={projectId} viewMode="kanban" isDragging />
                ) : null}
            </DragOverlay>
        </DndContext>
    );
}
