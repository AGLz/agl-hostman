import { useState, useEffect, useCallback } from 'react';
import axios from 'axios';

/**
 * Custom hook for fetching and managing network topology data
 */
export function useNetworkGraph() {
    const [graph, setGraph] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [lastUpdate, setLastUpdate] = useState(null);

    const fetchGraph = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await axios.get('/api/network/graph');
            setGraph(response.data);
            setLastUpdate(new Date());
        } catch (err) {
            setError(err.message);
            console.error('Failed to fetch network graph:', err);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchGraph();

        // Auto-refresh every 30 seconds
        const interval = setInterval(fetchGraph, 30000);

        return () => clearInterval(interval);
    }, [fetchGraph]);

    return {
        graph,
        loading,
        error,
        lastUpdate,
        refetch: fetchGraph,
    };
}

/**
 * Custom hook for fetching real-time node metrics
 */
export function useNodeMetrics(nodeId) {
    const [metrics, setMetrics] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const fetchMetrics = useCallback(async () => {
        if (!nodeId) return;

        try {
            setLoading(true);
            setError(null);
            const response = await axios.get(`/api/network/nodes/${nodeId}`);
            setMetrics(response.data);
        } catch (err) {
            setError(err.message);
            console.error('Failed to fetch node metrics:', err);
        } finally {
            setLoading(false);
        }
    }, [nodeId]);

    useEffect(() => {
        fetchMetrics();

        // Auto-refresh every 5 seconds for real-time metrics
        const interval = setInterval(fetchMetrics, 5000);

        return () => clearInterval(interval);
    }, [fetchMetrics]);

    return {
        metrics,
        loading,
        error,
        refetch: fetchMetrics,
    };
}

/**
 * Custom hook for fetching connection health between two nodes
 */
export function useConnectionHealth(sourceId, targetId) {
    const [health, setHealth] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const fetchHealth = useCallback(async () => {
        if (!sourceId || !targetId) return;

        try {
            setLoading(true);
            setError(null);
            const response = await axios.get(`/api/network/connections/${sourceId}/${targetId}`);
            setHealth(response.data);
        } catch (err) {
            setError(err.message);
            console.error('Failed to fetch connection health:', err);
        } finally {
            setLoading(false);
        }
    }, [sourceId, targetId]);

    useEffect(() => {
        fetchHealth();

        // Auto-refresh every 10 seconds
        const interval = setInterval(fetchHealth, 10000);

        return () => clearInterval(interval);
    }, [fetchHealth]);

    return {
        health,
        loading,
        error,
        refetch: fetchHealth,
    };
}

/**
 * Custom hook for fetching network health metrics
 */
export function useNetworkHealth() {
    const [health, setHealth] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const fetchHealth = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await axios.get('/api/network/health');
            setHealth(response.data);
        } catch (err) {
            setError(err.message);
            console.error('Failed to fetch network health:', err);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchHealth();

        // Auto-refresh every 15 seconds
        const interval = setInterval(fetchHealth, 15000);

        return () => clearInterval(interval);
    }, [fetchHealth]);

    return {
        health,
        loading,
        error,
        refetch: fetchHealth,
    };
}

/**
 * Custom hook for detecting network issues
 */
export function useNetworkIssues() {
    const [issues, setIssues] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const fetchIssues = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await axios.get('/api/network/issues');
            setIssues(response.data);
        } catch (err) {
            setError(err.message);
            console.error('Failed to fetch network issues:', err);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchIssues();

        // Auto-refresh every 20 seconds
        const interval = setInterval(fetchIssues, 20000);

        return () => clearInterval(interval);
    }, [fetchIssues]);

    return {
        issues,
        loading,
        error,
        refetch: fetchIssues,
    };
}
