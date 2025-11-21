import React, { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Plus, Clock, CheckCircle, AlertCircle, Zap, User, Tag } from 'lucide-react';

function ScrumBoard() {
    const [board, setBoard] = useState({
        sprint_id: null,
        columns: {
            backlog: [],
            todo: [],
            in_progress: [],
            review: [],
            done: []
        }
    });
    const [loading, setLoading] = useState(true);
    const [draggedTask, setDraggedTask] = useState(null);

    useEffect(() => {
        fetchBoard();
    }, []);

    const fetchBoard = async () => {
        try {
            const response = await fetch('/api/scrum/board', {
                headers: {
                    'Accept': 'application/json',
                },
            });
            if (response.ok) {
                const data = await response.json();
                setBoard(data);
            }
        } catch (error) {
            console.error('Failed to fetch board:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleDragStart = (e, task, column) => {
        setDraggedTask({ task, column });
        e.dataTransfer.effectAllowed = 'move';
    };

    const handleDragOver = (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
    };

    const handleDrop = async (e, targetColumn) => {
        e.preventDefault();
        
        if (!draggedTask || draggedTask.column === targetColumn) {
            return;
        }

        const { task, column: sourceColumn } = draggedTask;
        
        // Optimistically update UI
        setBoard(prev => ({
            ...prev,
            columns: {
                ...prev.columns,
                [sourceColumn]: prev.columns[sourceColumn].filter(t => t.id !== task.id),
                [targetColumn]: [...prev.columns[targetColumn], task]
            }
        }));

        // Send update to server
        try {
            const response = await fetch(`/api/scrum/tasks/${task.id}/move`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                },
                body: JSON.stringify({ status: targetColumn }),
            });

            if (!response.ok) {
                // Revert on error
                fetchBoard();
            }
        } catch (error) {
            console.error('Failed to move task:', error);
            fetchBoard();
        }

        setDraggedTask(null);
    };

    const getColumnTitle = (column) => {
        const titles = {
            backlog: 'Backlog',
            todo: 'To Do',
            in_progress: 'In Progress',
            review: 'Review',
            done: 'Done'
        };
        return titles[column] || column;
    };

    const getColumnColor = (column) => {
        const colors = {
            backlog: 'bg-gray-100',
            todo: 'bg-blue-100',
            in_progress: 'bg-yellow-100',
            review: 'bg-purple-100',
            done: 'bg-green-100'
        };
        return colors[column] || 'bg-gray-100';
    };

    const getPriorityIcon = (priority) => {
        switch (priority) {
            case 'critical':
                return <AlertCircle className="h-4 w-4 text-red-500" />;
            case 'high':
                return <Zap className="h-4 w-4 text-orange-500" />;
            case 'medium':
                return <Clock className="h-4 w-4 text-yellow-500" />;
            default:
                return null;
        }
    };

    if (loading) {
        return <div className="flex items-center justify-center h-screen">Loading...</div>;
    }

    return (
        <div className="min-h-screen bg-gray-50 p-6">
            {/* Header */}
            <div className="mb-6">
                <h1 className="text-3xl font-bold text-gray-900 mb-2">Scrum Board</h1>
                <div className="flex items-center justify-between">
                    <div className="text-sm text-gray-500">
                        Sprint: {board.sprint_id ? `Active Sprint` : 'No active sprint'}
                    </div>
                    <Button className="flex items-center gap-2">
                        <Plus className="h-4 w-4" />
                        New Task
                    </Button>
                </div>
            </div>

            {/* Board Columns */}
            <div className="grid grid-cols-5 gap-4">
                {Object.entries(board.columns).map(([column, tasks]) => (
                    <div 
                        key={column}
                        className={`${getColumnColor(column)} rounded-lg p-4 min-h-[600px]`}
                        onDragOver={handleDragOver}
                        onDrop={(e) => handleDrop(e, column)}
                    >
                        <div className="mb-4">
                            <h2 className="font-semibold text-gray-700">
                                {getColumnTitle(column)}
                            </h2>
                            <span className="text-xs text-gray-500">
                                {tasks.length} {tasks.length === 1 ? 'task' : 'tasks'}
                            </span>
                        </div>

                        <div className="space-y-3">
                            {tasks.map(task => (
                                <TaskCard 
                                    key={task.id}
                                    task={task}
                                    column={column}
                                    onDragStart={handleDragStart}
                                />
                            ))}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}

function TaskCard({ task, column, onDragStart }) {
    const getPriorityColor = (priority) => {
        switch (priority) {
            case 'critical':
                return 'border-red-500';
            case 'high':
                return 'border-orange-500';
            case 'medium':
                return 'border-yellow-500';
            case 'low':
                return 'border-gray-300';
            default:
                return 'border-gray-200';
        }
    };

    return (
        <div
            draggable
            onDragStart={(e) => onDragStart(e, task, column)}
            className={`bg-white rounded-lg p-3 shadow-sm cursor-move hover:shadow-md transition-shadow border-l-4 ${getPriorityColor(task.priority)}`}
        >
            <div className="mb-2">
                <div className="flex items-start justify-between mb-1">
                    <h3 className="text-sm font-medium text-gray-900 flex-1">
                        {task.title}
                    </h3>
                    {task.priority && task.priority !== 'medium' && (
                        <PriorityBadge priority={task.priority} />
                    )}
                </div>
                
                {task.description && (
                    <p className="text-xs text-gray-500 line-clamp-2">
                        {task.description}
                    </p>
                )}
            </div>

            <div className="flex items-center justify-between text-xs">
                <div className="flex items-center gap-2">
                    {task.story_points && (
                        <span className="bg-blue-100 text-blue-700 px-2 py-0.5 rounded">
                            {task.story_points} pts
                        </span>
                    )}
                    {task.location && (
                        <span className="text-gray-400">
                            {task.location.code}
                        </span>
                    )}
                </div>

                {task.assignee && (
                    <div className="flex items-center gap-1 text-gray-500">
                        <User className="h-3 w-3" />
                        <span>{task.assignee.name.split(' ')[0]}</span>
                    </div>
                )}
            </div>

            {task.tags && task.tags.length > 0 && (
                <div className="flex flex-wrap gap-1 mt-2">
                    {task.tags.slice(0, 3).map(tag => (
                        <span key={tag} className="inline-flex items-center gap-0.5 text-xs text-gray-500">
                            <Tag className="h-2.5 w-2.5" />
                            {tag}
                        </span>
                    ))}
                </div>
            )}
        </div>
    );
}

function PriorityBadge({ priority }) {
    const getIcon = () => {
        switch (priority) {
            case 'critical':
                return <AlertCircle className="h-3 w-3" />;
            case 'high':
                return <Zap className="h-3 w-3" />;
            case 'low':
                return <CheckCircle className="h-3 w-3" />;
            default:
                return null;
        }
    };

    const getColor = () => {
        switch (priority) {
            case 'critical':
                return 'text-red-600 bg-red-50';
            case 'high':
                return 'text-orange-600 bg-orange-50';
            case 'low':
                return 'text-gray-600 bg-gray-50';
            default:
                return 'text-gray-500 bg-gray-50';
        }
    };

    return (
        <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${getColor()}`}>
            {getIcon()}
        </span>
    );
}

export default ScrumBoard;