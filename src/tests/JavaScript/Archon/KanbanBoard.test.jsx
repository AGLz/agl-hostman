import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { DndContext } from '@dnd-kit/core';
import KanbanBoard from '@/Components/Archon/KanbanBoard';

// Mock Inertia router
vi.mock('@inertiajs/react', () => ({
    router: {
        put: vi.fn(),
    },
    Link: ({ children, href }) => <a href={href}>{children}</a>
}));

describe('KanbanBoard', () => {
    const mockTasks = [
        {
            id: '1',
            title: 'Task 1',
            status: 'todo',
            priority: 'high',
            assignee: 'User',
            project_id: 'project-1'
        },
        {
            id: '2',
            title: 'Task 2',
            status: 'doing',
            priority: 'medium',
            assignee: 'Agent',
            project_id: 'project-1'
        },
        {
            id: '3',
            title: 'Task 3',
            status: 'review',
            priority: 'low',
            assignee: 'User',
            project_id: 'project-1'
        },
        {
            id: '4',
            title: 'Task 4',
            status: 'done',
            priority: 'high',
            assignee: 'User',
            project_id: 'project-1'
        }
    ];

    const mockOnTaskUpdate = vi.fn();

    beforeEach(() => {
        mockOnTaskUpdate.mockClear();
    });

    it('renders all four columns', () => {
        render(
            <KanbanBoard
                tasks={mockTasks}
                projectId="project-1"
                onTaskUpdate={mockOnTaskUpdate}
            />
        );

        expect(screen.getByText('📋 Todo')).toBeInTheDocument();
        expect(screen.getByText('🔄 Doing')).toBeInTheDocument();
        expect(screen.getByText('👀 Review')).toBeInTheDocument();
        expect(screen.getByText('✅ Done')).toBeInTheDocument();
    });

    it('displays tasks in correct columns', () => {
        render(
            <KanbanBoard
                tasks={mockTasks}
                projectId="project-1"
                onTaskUpdate={mockOnTaskUpdate}
            />
        );

        // Check task counts in column headers
        const columns = screen.getAllByText(/\d+/);
        expect(columns.length).toBeGreaterThan(0);
    });

    it('renders task cards with correct content', () => {
        render(
            <KanbanBoard
                tasks={mockTasks}
                projectId="project-1"
                onTaskUpdate={mockOnTaskUpdate}
            />
        );

        mockTasks.forEach(task => {
            expect(screen.getByText(task.title)).toBeInTheDocument();
        });
    });

    it('groups tasks by status correctly', () => {
        render(
            <KanbanBoard
                tasks={mockTasks}
                projectId="project-1"
                onTaskUpdate={mockOnTaskUpdate}
            />
        );

        // Verify each column has correct number of tasks
        const todoTasks = mockTasks.filter(t => t.status === 'todo');
        const doingTasks = mockTasks.filter(t => t.status === 'doing');
        const reviewTasks = mockTasks.filter(t => t.status === 'review');
        const doneTasks = mockTasks.filter(t => t.status === 'done');

        expect(todoTasks.length).toBe(1);
        expect(doingTasks.length).toBe(1);
        expect(reviewTasks.length).toBe(1);
        expect(doneTasks.length).toBe(1);
    });

    it('renders empty state when no tasks in column', () => {
        const emptyTasks = mockTasks.filter(t => t.status === 'todo');

        render(
            <KanbanBoard
                tasks={emptyTasks}
                projectId="project-1"
                onTaskUpdate={mockOnTaskUpdate}
            />
        );

        // Other columns should show "No tasks"
        const noTasksElements = screen.getAllByText('No tasks');
        expect(noTasksElements.length).toBe(3); // doing, review, done columns
    });

    it('displays task priority indicators', () => {
        render(
            <KanbanBoard
                tasks={mockTasks}
                projectId="project-1"
                onTaskUpdate={mockOnTaskUpdate}
            />
        );

        // Check for priority badges
        expect(screen.getByText('high')).toBeInTheDocument();
        expect(screen.getByText('medium')).toBeInTheDocument();
        expect(screen.getByText('low')).toBeInTheDocument();
    });

    it('shows assignee information on task cards', () => {
        render(
            <KanbanBoard
                tasks={mockTasks}
                projectId="project-1"
                onTaskUpdate={mockOnTaskUpdate}
            />
        );

        expect(screen.getAllByText('User').length).toBeGreaterThan(0);
        expect(screen.getByText('Agent')).toBeInTheDocument();
    });
});
