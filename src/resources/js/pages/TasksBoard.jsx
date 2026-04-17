import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
    DndContext,
    closestCenter,
    KeyboardSensor,
    PointerSensor,
    useSensor,
    useSensors,
    DragOverlay,
} from '@dnd-kit/core';
import {
    SortableContext,
    sortableKeyboardCoordinates,
    verticalListSortingStrategy,
    useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import {
    Plus,
    Search,
    Filter,
    Clock,
    Flag,
    MoreHorizontal,
    User,
    Calendar,
    X,
    CheckCircle2,
    AlertCircle,
    Loader2,
    ChevronDown
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';


const COLUMNS = [
    { id: 'backlog', title: 'Backlog', color: 'from-gray-500 to-gray-600' },
    { id: 'in-progress', title: 'In Progress', color: 'from-blue-500 to-blue-600' },
    { id: 'review', title: 'Review', color: 'from-yellow-500 to-orange-500' },
    { id: 'done', title: 'Done', color: 'from-green-500 to-emerald-600' },
];

const PRIORITIES = {
    low: { label: 'Low', color: 'bg-gray-500/10 text-gray-400', icon: Flag },
    medium: { label: 'Medium', color: 'bg-blue-500/10 text-blue-400', icon: Flag },
    high: { label: 'High', color: 'bg-orange-500/10 text-orange-400', icon: Flag },
    urgent: { label: 'Urgent', color: 'bg-red-500/10 text-red-400', icon: AlertCircle },
};

const ASSIGNABLE_USERS = ['Me', 'main', 'devops', 'security', 'infra-manager', 'sre-team'];

// Sample tasks
const INITIAL_TASKS = [
    { id: 't1', title: 'Update LiteLLM config for qwen3.5-flash', assignee: 'devops', priority: 'high', status: 'done', dueDate: '2026-04-13', project: 'Infrastructure', description: 'Configure all models to use qwen3.5-flash as default' },
    { id: 't2', title: 'Fix OpenClaw cron job IPs', assignee: 'main', priority: 'urgent', status: 'done', dueDate: '2026-04-13', project: 'OpenClaw', description: 'Update n8n and wg-easy health check IPs' },
    { id: 't3', title: 'Add Mission Control routes', assignee: 'Me', priority: 'high', status: 'in-progress', dueDate: '2026-04-14', project: 'Dashboard', description: 'Create routes for all Mission Control pages' },
    { id: 't4', title: 'Implement agent status API', assignee: 'devops', priority: 'medium', status: 'in-progress', dueDate: '2026-04-15', project: 'API', description: 'Create /api/agents endpoint for real-time status' },
    { id: 't5', title: 'Set up Grafana dashboards', assignee: 'sre-team', priority: 'medium', status: 'backlog', dueDate: '2026-04-20', project: 'Monitoring', description: 'Create Grafana panels for infrastructure metrics' },
    { id: 't6', title: 'Review security audit results', assignee: 'security', priority: 'high', status: 'review', dueDate: '2026-04-14', project: 'Security', description: 'Analyze latest vulnerability scan findings' },
    { id: 't7', title: 'Update Proxmox documentation', assignee: 'infra-manager', priority: 'low', status: 'backlog', dueDate: '2026-04-25', project: 'Documentation', description: 'Document new CT/VM configurations' },
    { id: 't8', title: 'Optimize Docker compose stacks', assignee: 'devops', priority: 'medium', status: 'backlog', dueDate: '2026-04-18', project: 'Infrastructure', description: 'Reduce resource usage of monitoring stack' },
];

function SortableTask({ task, onClick }) {
    const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: task.id });

    const style = {
        transform: CSS.Transform.toString(transform),
        transition,
        opacity: isDragging ? 0.5 : 1,
    };

    const priority = PRIORITIES[task.priority] || PRIORITIES.medium;

    return (
        <div
            ref={setNodeRef}
            style={style}
            className="p-3 rounded-lg bg-white/[0.04] border border-white/5 hover:bg-white/[0.06] hover:border-white/10 transition-all cursor-pointer mb-2 last:mb-0"
            onClick={() => onClick(task)}
            {...attributes}
            {...listeners}
        >
            <div className="flex items-start justify-between gap-2">
                <p className="text-xs font-medium text-white/80 line-clamp-2">{task.title}</p>
                <MoreHorizontal className="w-3.5 h-3.5 text-white/20 shrink-0" />
            </div>

            <div className="flex items-center gap-2 mt-2 flex-wrap">
                <Badge variant="secondary" className={cn("text-[9px] border-none", priority.color)}>
                    <priority.icon className="w-2.5 h-2.5 mr-0.5" />
                    {priority.label}
                </Badge>
                {task.assignee && (
                    <span className="text-[10px] text-white/30 flex items-center gap-0.5">
                        <User className="w-2.5 h-2.5" />
                        {task.assignee}
                    </span>
                )}
                {task.dueDate && (
                    <span className="text-[10px] text-white/30 flex items-center gap-0.5">
                        <Calendar className="w-2.5 h-2.5" />
                        {new Date(task.dueDate).toLocaleDateString('en', { month: 'short', day: 'numeric' })}
                    </span>
                )}
            </div>

            {task.project && (
                <p className="text-[10px] text-white/20 mt-1.5">{task.project}</p>
            )}
        </div>
    );
}

function TaskColumn({ column, tasks, onTaskClick }) {
    return (
        <div className="flex-1 min-w-[280px]">
            <div className="flex items-center gap-2 mb-3 px-1">
                <div className={cn("w-2 h-2 rounded-full bg-gradient-to-r", column.color)} />
                <h3 className="text-sm font-medium text-white/70">{column.title}</h3>
                <Badge variant="secondary" className="bg-white/5 text-white/30 border-none text-[10px] ml-auto">
                    {tasks.length}
                </Badge>
            </div>

            <div className="space-y-0 min-h-[200px] p-2 rounded-lg bg-white/[0.01] border border-dashed border-white/5">
                <SortableContext items={tasks.map(t => t.id)} strategy={verticalListSortingStrategy}>
                    {tasks.map(task => (
                        <SortableTask key={task.id} task={task} onClick={onTaskClick} />
                    ))}
                </SortableContext>

                {tasks.length === 0 && (
                    <div className="flex items-center justify-center py-8 text-white/20 text-xs">
                        No tasks
                    </div>
                )}
            </div>
        </div>
    );
}

function TaskDetailModal({ task, onClose, onUpdate }) {
    if (!task) return null;

    const priority = PRIORITIES[task.priority] || PRIORITIES.medium;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onClose}>
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="w-full max-w-lg mx-4 bg-[#1a1a24] border border-white/10 rounded-xl p-6 max-h-[80vh] overflow-y-auto"
                onClick={e => e.stopPropagation()}
            >
                <div className="flex items-start justify-between mb-4">
                    <div className="flex-1">
                        <h3 className="text-lg font-semibold text-white">{task.title}</h3>
                        <div className="flex items-center gap-2 mt-2">
                            <Badge variant="secondary" className={cn("text-[10px] border-none", priority.color)}>
                                {priority.label}
                            </Badge>
                            <span className="text-xs text-white/40">{task.status}</span>
                        </div>
                    </div>
                    <button onClick={onClose} className="text-white/40 hover:text-white">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="space-y-4">
                    {task.description && (
                        <div>
                            <p className="text-xs text-white/40 mb-1">Description</p>
                            <p className="text-sm text-white/70">{task.description}</p>
                        </div>
                    )}

                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <p className="text-xs text-white/40 mb-1">Assignee</p>
                            <select
                                value={task.assignee || ''}
                                onChange={e => onUpdate({ ...task, assignee: e.target.value })}
                                className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white"
                            >
                                <option value="">Unassigned</option>
                                {ASSIGNABLE_USERS.map(u => (
                                    <option key={u} value={u}>{u}</option>
                                ))}
                            </select>
                        </div>
                        <div>
                            <p className="text-xs text-white/40 mb-1">Priority</p>
                            <select
                                value={task.priority}
                                onChange={e => onUpdate({ ...task, priority: e.target.value })}
                                className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white"
                            >
                                {Object.entries(PRIORITIES).map(([key, val]) => (
                                    <option key={key} value={key}>{val.label}</option>
                                ))}
                            </select>
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <p className="text-xs text-white/40 mb-1">Status</p>
                            <select
                                value={task.status}
                                onChange={e => onUpdate({ ...task, status: e.target.value })}
                                className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white"
                            >
                                {COLUMNS.map(col => (
                                    <option key={col.id} value={col.id}>{col.title}</option>
                                ))}
                            </select>
                        </div>
                        <div>
                            <p className="text-xs text-white/40 mb-1">Due Date</p>
                            <input
                                type="date"
                                value={task.dueDate || ''}
                                onChange={e => onUpdate({ ...task, dueDate: e.target.value })}
                                className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white"
                            />
                        </div>
                    </div>
                </div>

                <div className="mt-6 flex gap-2">
                    <button
                        onClick={onClose}
                        className="flex-1 py-2 rounded-lg bg-white/5 hover:bg-white/10 text-white/60 hover:text-white text-sm transition-colors"
                    >
                        Close
                    </button>
                </div>
            </motion.div>
        </div>
    );
}

export default function TasksBoard() {
    const [tasks, setTasks] = useState(INITIAL_TASKS);
    const [searchQuery, setSearchQuery] = useState('');
    const [priorityFilter, setPriorityFilter] = useState('all');
    const [selectedTask, setSelectedTask] = useState(null);
    const [activeId, setActiveId] = useState(null);

    const sensors = useSensors(
        useSensor(PointerSensor, { activationConstraint: { distance: 8 } }),
        useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
    );

    const handleDragStart = (event) => setActiveId(event.active.id);
    const handleDragEnd = (event) => {
        const { active, over } = event;
        if (over && active.id !== over.id) {
            setTasks(prev => prev.map(t =>
                t.id === active.id ? { ...t, status: over.id } : t
            ));
        }
        setActiveId(null);
    };

    const handleDragCancel = () => setActiveId(null);

    const handleTaskUpdate = (updatedTask) => {
        setTasks(prev => prev.map(t => t.id === updatedTask.id ? updatedTask : t));
        setSelectedTask(null);
    };

    const filteredTasks = tasks.filter(task => {
        const matchesSearch = task.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
                             task.project?.toLowerCase().includes(searchQuery.toLowerCase());
        const matchesPriority = priorityFilter === 'all' || task.priority === priorityFilter;
        return matchesSearch && matchesPriority;
    });

    const tasksByColumn = {};
    COLUMNS.forEach(col => {
        tasksByColumn[col.id] = filteredTasks.filter(t => t.status === col.id);
    });

    const activeTask = activeId ? tasks.find(t => t.id === activeId) : null;

    return (
        
            <div className="space-y-6">
                {/* Header */}
                <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                    <div>
                        <h1 className="text-2xl font-bold text-white">Tasks Board</h1>
                        <p className="text-sm text-white/40 mt-1">{tasks.length} tasks across {COLUMNS.length} stages</p>
                    </div>
                    <Button className="bg-blue-600 hover:bg-blue-700 text-white">
                        <Plus className="w-4 h-4 mr-1.5" />
                        New Task
                    </Button>
                </div>

                {/* Filters */}
                <div className="flex flex-col sm:flex-row gap-3">
                    <div className="relative flex-1">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30" />
                        <Input
                            placeholder="Search tasks..."
                            value={searchQuery}
                            onChange={e => setSearchQuery(e.target.value)}
                            className="pl-9 bg-white/5 border-white/10 text-white placeholder:text-white/30"
                        />
                    </div>
                    <div className="flex gap-2">
                        {Object.entries(PRIORITIES).map(([key, val]) => (
                            <button
                                key={key}
                                onClick={() => setPriorityFilter(priorityFilter === key ? 'all' : key)}
                                className={cn(
                                    "px-3 py-1.5 rounded-lg text-xs font-medium transition-colors flex items-center gap-1",
                                    priorityFilter === key
                                        ? "bg-white/10 text-white"
                                        : "bg-white/5 text-white/40 hover:text-white/60"
                                )}
                            >
                                <val.icon className="w-3 h-3" />
                                {val.label}
                            </button>
                        ))}
                    </div>
                </div>

                {/* Kanban Board */}
                <DndContext
                    sensors={sensors}
                    collisionDetection={closestCenter}
                    onDragStart={handleDragStart}
                    onDragEnd={handleDragEnd}
                    onDragCancel={handleDragCancel}
                >
                    <div className="flex gap-4 overflow-x-auto pb-4 -mx-2 px-2">
                        {COLUMNS.map(column => (
                            <TaskColumn
                                key={column.id}
                                column={column}
                                tasks={tasksByColumn[column.id]}
                                onTaskClick={setSelectedTask}
                            />
                        ))}
                    </div>

                    <DragOverlay>
                        {activeTask ? (
                            <div className="p-3 rounded-lg bg-[#1a1a24] border border-white/10 shadow-xl w-[280px]">
                                <p className="text-xs font-medium text-white">{activeTask.title}</p>
                            </div>
                        ) : null}
                    </DragOverlay>
                </DndContext>

                {/* Task Detail Modal */}
                <TaskDetailModal
                    task={selectedTask}
                    onClose={() => setSelectedTask(null)}
                    onUpdate={handleTaskUpdate}
                />
            </div>
        
    );
}
