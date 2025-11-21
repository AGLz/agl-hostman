/**
 * useContainerLifecycle Hook
 *
 * Manages container lifecycle operations (create, clone, migrate, backup, restore, snapshot, rollback)
 */
import { useState, useCallback } from 'react';
import { useContainerStatus } from './useContainerStatus';

/**
 * Container lifecycle operations hook
 *
 * @param {number} vmid - Container VMID to manage (optional for create/restore)
 * @param {object} options - Additional options
 * @returns {object} Lifecycle operations and state
 */
export const useContainerLifecycle = (vmid = null, options = {}) => {
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [lastResult, setLastResult] = useState(null);
    const [snapshots, setSnapshots] = useState([]);
    const [backups, setBackups] = useState([]);

    // Real-time status updates if vmid provided
    const containerStatus = vmid ? useContainerStatus(vmid, options) : null;

    /**
     * Generic API request handler
     */
    const apiRequest = useCallback(async (endpoint, method = 'POST', body = null) => {
        setLoading(true);
        setError(null);

        try {
            const response = await fetch(endpoint, {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                },
                body: body ? JSON.stringify(body) : null,
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.message || data.error || `Request failed: ${response.status}`);
            }

            setLastResult(data);
            return { success: true, data };
        } catch (err) {
            const errorMessage = err.message || 'Request failed';
            setError(errorMessage);
            return { success: false, error: errorMessage };
        } finally {
            setLoading(false);
        }
    }, []);

    /**
     * Create new container
     */
    const createContainer = useCallback(async (node, vmid, config) => {
        return await apiRequest('/api/containers/create', 'POST', {
            node,
            vmid,
            ...config,
        });
    }, [apiRequest]);

    /**
     * Clone existing container
     */
    const cloneContainer = useCallback(async (sourceVmid, newVmid, options = {}) => {
        return await apiRequest(`/api/containers/${sourceVmid}/clone`, 'POST', {
            newVmid,
            ...options,
        });
    }, [apiRequest]);

    /**
     * Migrate container to another node
     */
    const migrateContainer = useCallback(async (vmid, targetNode, options = {}) => {
        return await apiRequest(`/api/containers/${vmid}/migrate`, 'POST', {
            target_node: targetNode,
            ...options,
        });
    }, [apiRequest]);

    /**
     * Create container backup
     */
    const backupContainer = useCallback(async (vmid, options = {}) => {
        return await apiRequest(`/api/containers/${vmid}/backup`, 'POST', options);
    }, [apiRequest]);

    /**
     * Restore container from backup
     */
    const restoreContainer = useCallback(async (storage, volume, vmid, options = {}) => {
        return await apiRequest('/api/containers/restore', 'POST', {
            storage,
            volume,
            vmid,
            ...options,
        });
    }, [apiRequest]);

    /**
     * Create container snapshot
     */
    const createSnapshot = useCallback(async (vmid, snapname, description = '') => {
        return await apiRequest(`/api/containers/${vmid}/snapshot`, 'POST', {
            snapname,
            description,
        });
    }, [apiRequest]);

    /**
     * Rollback to snapshot
     */
    const rollbackToSnapshot = useCallback(async (vmid, snapname) => {
        return await apiRequest(`/api/containers/${vmid}/rollback`, 'POST', {
            snapname,
        });
    }, [apiRequest]);

    /**
     * List container snapshots
     */
    const listSnapshots = useCallback(async (vmid) => {
        const result = await apiRequest(`/api/containers/${vmid}/snapshots`, 'GET');
        if (result.success && result.data.snapshots) {
            setSnapshots(result.data.snapshots);
        }
        return result;
    }, [apiRequest]);

    /**
     * List available backups
     */
    const listBackups = useCallback(async (node = null, vmid = null) => {
        const params = new URLSearchParams();
        if (node) params.append('node', node);
        if (vmid) params.append('vmid', vmid);

        const result = await apiRequest(`/api/containers/backups?${params}`, 'GET');
        if (result.success && result.data.backups) {
            setBackups(result.data.backups);
        }
        return result;
    }, [apiRequest]);

    /**
     * Clear error state
     */
    const clearError = useCallback(() => {
        setError(null);
    }, []);

    /**
     * Clear last result
     */
    const clearResult = useCallback(() => {
        setLastResult(null);
    }, []);

    return {
        // Operations
        createContainer,
        cloneContainer,
        migrateContainer,
        backupContainer,
        restoreContainer,
        createSnapshot,
        rollbackToSnapshot,
        listSnapshots,
        listBackups,

        // State
        loading,
        error,
        lastResult,
        snapshots,
        backups,

        // Real-time status (if vmid provided)
        containerStatus,

        // Utilities
        clearError,
        clearResult,
    };
};

export default useContainerLifecycle;
