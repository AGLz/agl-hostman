import { useState, useEffect } from 'react';
import { router } from '@inertiajs/react';

/**
 * Custom hook for fetching and caching Archon data
 *
 * @param {Object} options - Configuration options
 * @param {string} options.endpoint - API endpoint to fetch from
 * @param {Object} options.params - Query parameters
 * @param {boolean} options.autoFetch - Whether to fetch on mount (default: true)
 * @param {number} options.cacheTime - Cache duration in ms (default: 5 minutes)
 * @returns {Object} - { data, isLoading, error, refetch }
 */
export function useArchon({ endpoint, params = {}, autoFetch = true, cacheTime = 300000 }) {
    const [data, setData] = useState(null);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState(null);
    const [lastFetch, setLastFetch] = useState(null);

    const fetchData = async (force = false) => {
        // Check cache
        if (!force && lastFetch && Date.now() - lastFetch < cacheTime) {
            return;
        }

        setIsLoading(true);
        setError(null);

        try {
            const queryString = new URLSearchParams(params).toString();
            const url = queryString ? `${endpoint}?${queryString}` : endpoint;

            const response = await fetch(url, {
                headers: {
                    'Accept': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const result = await response.json();
            setData(result);
            setLastFetch(Date.now());
        } catch (err) {
            setError(err.message);
            console.error('Archon fetch error:', err);
        } finally {
            setIsLoading(false);
        }
    };

    useEffect(() => {
        if (autoFetch) {
            fetchData();
        }
    }, [endpoint, JSON.stringify(params), autoFetch]);

    const refetch = () => fetchData(true);

    return {
        data,
        isLoading,
        error,
        refetch,
        isCached: lastFetch && Date.now() - lastFetch < cacheTime
    };
}
