import { useState, useEffect } from 'react';
import { router } from '@inertiajs/react';

export function useDokploy() {
    const [projects, setProjects] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const fetchProjects = async () => {
        setLoading(true);
        setError(null);

        try {
            const response = await fetch('/api/dokploy/projects', {
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (!response.ok) {
                throw new Error('Failed to fetch projects');
            }

            const data = await response.json();
            setProjects(data);
        } catch (err) {
            setError(err.message);
            console.error('Error fetching projects:', err);
        } finally {
            setLoading(false);
        }
    };

    const refreshProjects = () => {
        fetchProjects();
    };

    useEffect(() => {
        fetchProjects();
    }, []);

    return {
        projects,
        loading,
        error,
        refresh: refreshProjects,
    };
}

export function useProject(projectId) {
    const [project, setProject] = useState(null);
    const [applications, setApplications] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const fetchProject = async () => {
        if (!projectId) return;

        setLoading(true);
        setError(null);

        try {
            const response = await fetch(`/api/dokploy/projects/${projectId}`, {
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (!response.ok) {
                throw new Error('Failed to fetch project');
            }

            const data = await response.json();
            setProject(data.project);
            setApplications(data.applications || []);
        } catch (err) {
            setError(err.message);
            console.error('Error fetching project:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchProject();
    }, [projectId]);

    return {
        project,
        applications,
        loading,
        error,
        refresh: fetchProject,
    };
}

export function useApplication(applicationId) {
    const [application, setApplication] = useState(null);
    const [deployments, setDeployments] = useState([]);
    const [domains, setDomains] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const fetchApplication = async () => {
        if (!applicationId) return;

        setLoading(true);
        setError(null);

        try {
            const response = await fetch(`/api/dokploy/applications/${applicationId}`, {
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (!response.ok) {
                throw new Error('Failed to fetch application');
            }

            const data = await response.json();
            setApplication(data.application);
            setDeployments(data.deployments || []);
            setDomains(data.domains || []);
        } catch (err) {
            setError(err.message);
            console.error('Error fetching application:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchApplication();
    }, [applicationId]);

    return {
        application,
        deployments,
        domains,
        loading,
        error,
        refresh: fetchApplication,
    };
}
