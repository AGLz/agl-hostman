import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import DeploymentPipeline from '@/Components/Dokploy/DeploymentPipeline';

const mockDeployments = [
    {
        id: 1,
        status: 'done',
        created_at: '2025-01-01T10:00:00Z',
        application: { environment: 'dev' },
    },
    {
        id: 2,
        status: 'done',
        created_at: '2025-01-01T12:00:00Z',
        application: { environment: 'qa' },
    },
    {
        id: 3,
        status: 'running',
        created_at: '2025-01-01T14:00:00Z',
        application: { environment: 'uat' },
    },
    {
        id: 4,
        status: 'error',
        created_at: '2025-01-01T16:00:00Z',
        application: { environment: 'prod' },
    },
];

describe('DeploymentPipeline', () => {
    it('renders all environments', () => {
        render(<DeploymentPipeline projectId="1" deployments={mockDeployments} />);

        expect(screen.getByText('DEV')).toBeInTheDocument();
        expect(screen.getByText('QA')).toBeInTheDocument();
        expect(screen.getByText('UAT')).toBeInTheDocument();
        expect(screen.getByText('PROD')).toBeInTheDocument();
    });

    it('shows correct status for each environment', () => {
        render(<DeploymentPipeline projectId="1" deployments={mockDeployments} />);

        expect(screen.getByText('SUCCESS')).toBeInTheDocument();
        expect(screen.getByText('IN_PROGRESS')).toBeInTheDocument();
        expect(screen.getByText('FAILED')).toBeInTheDocument();
    });

    it('displays deployment timestamps', () => {
        render(<DeploymentPipeline projectId="1" deployments={mockDeployments} />);

        expect(screen.getByText(/Jan 01/)).toBeInTheDocument();
    });

    it('renders legend with status indicators', () => {
        render(<DeploymentPipeline projectId="1" deployments={mockDeployments} />);

        expect(screen.getByText('Success')).toBeInTheDocument();
        expect(screen.getByText('In Progress')).toBeInTheDocument();
        expect(screen.getByText('Failed')).toBeInTheDocument();
        expect(screen.getByText('Not Deployed')).toBeInTheDocument();
    });

    it('handles empty deployments', () => {
        render(<DeploymentPipeline projectId="1" deployments={[]} />);

        const notDeployedBadges = screen.getAllByText('NOT_DEPLOYED');
        expect(notDeployedBadges).toHaveLength(4); // All 4 environments
    });
});
