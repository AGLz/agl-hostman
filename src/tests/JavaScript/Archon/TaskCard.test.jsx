import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import TaskCard from '@/Components/Archon/TaskCard';

// Mock Inertia router
vi.mock('@inertiajs/react', () => ({
    router: {
        put: vi.fn(),
        delete: vi.fn(),
    },
    Link: ({ children, href }) => <a href={href}>{children}</a>
}));

describe('TaskCard', () => {
    const mockTask = {
        id: '1',
        title: 'Test Task',
        description: 'This is a test task description',
        status: 'todo',
        priority: 'high',
        assignee: 'User',
        feature: 'authentication',
        task_order: 5,
        project_id: 'project-1',
        updated_at: '2025-01-01T00:00:00Z'
    };

    it('renders task title', () => {
        render(<TaskCard task={mockTask} projectId="project-1" />);
        expect(screen.getByText('Test Task')).toBeInTheDocument();
    });

    it('renders task description in kanban mode', () => {
        render(<TaskCard task={mockTask} projectId="project-1" viewMode="kanban" />);
        expect(screen.getByText(mockTask.description)).toBeInTheDocument();
    });

    it('displays priority badge with correct color', () => {
        render(<TaskCard task={mockTask} projectId="project-1" />);
        const priorityBadge = screen.getByText('high');
        expect(priorityBadge).toBeInTheDocument();
        expect(priorityBadge).toHaveClass('text-red-800');
    });

    it('shows feature tag when present', () => {
        render(<TaskCard task={mockTask} projectId="project-1" />);
        expect(screen.getByText('authentication')).toBeInTheDocument();
    });

    it('displays assignee information', () => {
        render(<TaskCard task={mockTask} projectId="project-1" />);
        expect(screen.getByText('User')).toBeInTheDocument();
        expect(screen.getByText('👤')).toBeInTheDocument();
    });

    it('shows task order number in kanban mode', () => {
        render(<TaskCard task={mockTask} projectId="project-1" viewMode="kanban" />);
        expect(screen.getByText('#5')).toBeInTheDocument();
    });

    it('renders status badge in list mode', () => {
        render(<TaskCard task={mockTask} projectId="project-1" viewMode="list" />);
        expect(screen.getByText('todo')).toBeInTheDocument();
    });

    it('has delete button', () => {
        render(<TaskCard task={mockTask} projectId="project-1" />);
        const deleteButton = screen.getByText('Delete');
        expect(deleteButton).toBeInTheDocument();
    });

    it('applies dragging opacity in kanban mode', () => {
        const { container } = render(
            <TaskCard task={mockTask} projectId="project-1" viewMode="kanban" isDragging={true} />
        );
        const card = container.firstChild;
        expect(card).toHaveClass('opacity-50');
    });

    it('shows status selector in list mode for non-done tasks', () => {
        render(<TaskCard task={mockTask} projectId="project-1" viewMode="list" />);
        const statusSelect = screen.getByRole('combobox');
        expect(statusSelect).toBeInTheDocument();
    });

    it('hides status selector for done tasks in list mode', () => {
        const doneTask = { ...mockTask, status: 'done' };
        render(<TaskCard task={doneTask} projectId="project-1" viewMode="list" />);
        const statusSelect = screen.queryByRole('combobox');
        expect(statusSelect).not.toBeInTheDocument();
    });

    it('renders correctly without optional fields', () => {
        const minimalTask = {
            id: '2',
            title: 'Minimal Task',
            status: 'todo',
            project_id: 'project-1',
            updated_at: '2025-01-01T00:00:00Z'
        };

        render(<TaskCard task={minimalTask} projectId="project-1" />);
        expect(screen.getByText('Minimal Task')).toBeInTheDocument();
    });

    it('truncates long titles in kanban mode', () => {
        const longTitleTask = {
            ...mockTask,
            title: 'This is a very long task title that should be truncated in kanban view to prevent overflow'
        };

        const { container } = render(
            <TaskCard task={longTitleTask} projectId="project-1" viewMode="kanban" />
        );

        const titleElement = container.querySelector('.line-clamp-2');
        expect(titleElement).toBeInTheDocument();
    });

    it('shows medium priority with correct styling', () => {
        const mediumPriorityTask = { ...mockTask, priority: 'medium' };
        render(<TaskCard task={mediumPriorityTask} projectId="project-1" />);

        const priorityBadge = screen.getByText('medium');
        expect(priorityBadge).toHaveClass('text-yellow-800');
    });

    it('shows low priority with correct styling', () => {
        const lowPriorityTask = { ...mockTask, priority: 'low' };
        render(<TaskCard task={lowPriorityTask} projectId="project-1" />);

        const priorityBadge = screen.getByText('low');
        expect(priorityBadge).toHaveClass('text-gray-800');
    });
});
