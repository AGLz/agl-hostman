import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import ProjectCard from '@/Components/Dokploy/ProjectCard';

const mockProject = {
    id: 1,
    name: 'Test Project',
    description: 'Test project description',
    status: 'active',
    applications: [
        { id: 1, status: 'running', environment: 'dev' },
        { id: 2, status: 'running', environment: 'prod' },
        { id: 3, status: 'stopped', environment: 'qa' },
    ],
    updated_at: '2025-01-01T00:00:00Z',
};

const renderWithRouter = (component) => {
    return render(
        <BrowserRouter>
            {component}
        </BrowserRouter>
    );
};

describe('ProjectCard', () => {
    it('renders project name', () => {
        renderWithRouter(<ProjectCard project={mockProject} />);
        expect(screen.getByText('Test Project')).toBeInTheDocument();
    });

    it('renders project description', () => {
        renderWithRouter(<ProjectCard project={mockProject} />);
        expect(screen.getByText('Test project description')).toBeInTheDocument();
    });

    it('displays correct application counts', () => {
        renderWithRouter(<ProjectCard project={mockProject} />);
        expect(screen.getByText(/2\/3/)).toBeInTheDocument();
        expect(screen.getByText(/active/i)).toBeInTheDocument();
    });

    it('shows status badge', () => {
        renderWithRouter(<ProjectCard project={mockProject} />);
        expect(screen.getByText('active')).toBeInTheDocument();
    });

    it('renders in grid view by default', () => {
        const { container } = renderWithRouter(<ProjectCard project={mockProject} />);
        expect(container.querySelector('.rounded-lg.shadow')).toBeInTheDocument();
    });

    it('renders in list view when specified', () => {
        renderWithRouter(<ProjectCard project={mockProject} viewMode="list" />);
        expect(screen.getByText('Active Apps')).toBeInTheDocument();
    });

    it('displays environment badges', () => {
        renderWithRouter(<ProjectCard project={mockProject} />);
        expect(screen.getByText('DEV')).toBeInTheDocument();
        expect(screen.getByText('PROD')).toBeInTheDocument();
        expect(screen.getByText('QA')).toBeInTheDocument();
    });

    it('links to project detail page', () => {
        const { container } = renderWithRouter(<ProjectCard project={mockProject} />);
        const link = container.querySelector('a');
        expect(link).toHaveAttribute('href', '/dokploy/projects/1');
    });
});
