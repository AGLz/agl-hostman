import { useState, useEffect } from 'react';
import { router } from '@inertiajs/react';

export function useDeployment(applicationId) {
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState(null);
    const [status, setStatus] = useState(null);

    const deploy = async (title = null, description = null) => {
        setIsLoading(true);
        setError(null);

        try {
            const response = await fetch(`/api/dokploy/applications/${applicationId}/deploy`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
                body: JSON.stringify({ title, description }),
            });

            if (!response.ok) {
                throw new Error('Deployment failed');
            }

            const data = await response.json();
            setStatus('deploying');

            // Optionally reload the page to show new deployment
            setTimeout(() => {
                router.reload();
            }, 2000);

            return data;
        } catch (err) {
            setError(err.message);
            console.error('Deployment error:', err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    };

    const stop = async () => {
        setIsLoading(true);
        setError(null);

        try {
            const response = await fetch(`/api/dokploy/applications/${applicationId}/stop`, {
                method: 'POST',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (!response.ok) {
                throw new Error('Stop failed');
            }

            setStatus('stopped');
            setTimeout(() => {
                router.reload();
            }, 1000);
        } catch (err) {
            setError(err.message);
            console.error('Stop error:', err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    };

    const restart = async () => {
        setIsLoading(true);
        setError(null);

        try {
            const response = await fetch(`/api/dokploy/applications/${applicationId}/restart`, {
                method: 'POST',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (!response.ok) {
                throw new Error('Restart failed');
            }

            setStatus('restarting');
            setTimeout(() => {
                router.reload();
            }, 2000);
        } catch (err) {
            setError(err.message);
            console.error('Restart error:', err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    };

    const rollback = async (deploymentId) => {
        setIsLoading(true);
        setError(null);

        try {
            const response = await fetch(`/api/dokploy/deployments/${deploymentId}/rollback`, {
                method: 'POST',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (!response.ok) {
                throw new Error('Rollback failed');
            }

            setStatus('rolling_back');
            setTimeout(() => {
                router.reload();
            }, 2000);
        } catch (err) {
            setError(err.message);
            console.error('Rollback error:', err);
            throw err;
        } finally {
            setIsLoading(false);
        }
    };

    return {
        deploy,
        stop,
        restart,
        rollback,
        isLoading,
        error,
        status,
    };
}

export function useDeploymentStatus(applicationId) {
    const [status, setStatus] = useState(null);
    const [loading, setLoading] = useState(false);

    const checkStatus = async () => {
        setLoading(true);

        try {
            const response = await fetch(`/api/dokploy/applications/${applicationId}/status`, {
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (response.ok) {
                const data = await response.json();
                setStatus(data.status);
            }
        } catch (err) {
            console.error('Status check error:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (!applicationId) return;

        checkStatus();

        // Poll every 5 seconds when deploying
        const interval = setInterval(() => {
            if (status === 'running' || status === 'deploying') {
                checkStatus();
            }
        }, 5000);

        return () => clearInterval(interval);
    }, [applicationId, status]);

    return {
        status,
        loading,
        refresh: checkStatus,
    };
}
