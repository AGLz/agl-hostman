import { useState, useEffect, useCallback, useRef } from 'react';
import { debounce } from 'lodash';

/**
 * Custom hook for autocomplete suggestions
 *
 * @param {Object} options - Configuration options
 * @param {Function} options.fetchSuggestions - Function to fetch suggestions (query) => Promise<Array>
 * @param {number} options.minLength - Minimum query length to trigger (default: 2)
 * @param {number} options.debounceMs - Debounce delay in ms (default: 300)
 * @param {number} options.maxSuggestions - Maximum suggestions to return (default: 10)
 * @returns {Object} - { suggestions, isLoading, getSuggestions, clearSuggestions }
 */
export function useAutoComplete({
    fetchSuggestions,
    minLength = 2,
    debounceMs = 300,
    maxSuggestions = 10
}) {
    const [suggestions, setSuggestions] = useState([]);
    const [isLoading, setIsLoading] = useState(false);
    const abortControllerRef = useRef(null);

    // Debounced fetch function
    const debouncedFetch = useCallback(
        debounce(async (query) => {
            if (!query || query.length < minLength) {
                setSuggestions([]);
                return;
            }

            // Abort previous request
            if (abortControllerRef.current) {
                abortControllerRef.current.abort();
            }

            abortControllerRef.current = new AbortController();

            setIsLoading(true);

            try {
                const results = await fetchSuggestions(query, abortControllerRef.current.signal);

                // Limit to maxSuggestions
                const limitedResults = results.slice(0, maxSuggestions);
                setSuggestions(limitedResults);
            } catch (err) {
                if (err.name !== 'AbortError') {
                    console.error('Autocomplete error:', err);
                    setSuggestions([]);
                }
            } finally {
                setIsLoading(false);
            }
        }, debounceMs),
        [fetchSuggestions, minLength, maxSuggestions, debounceMs]
    );

    const getSuggestions = useCallback((query) => {
        debouncedFetch(query);
    }, [debouncedFetch]);

    const clearSuggestions = useCallback(() => {
        setSuggestions([]);
        setIsLoading(false);
        if (abortControllerRef.current) {
            abortControllerRef.current.abort();
        }
    }, []);

    // Cleanup on unmount
    useEffect(() => {
        return () => {
            if (abortControllerRef.current) {
                abortControllerRef.current.abort();
            }
            debouncedFetch.cancel();
        };
    }, [debouncedFetch]);

    return {
        suggestions,
        isLoading,
        getSuggestions,
        clearSuggestions
    };
}

/**
 * Helper hook for creating a fetchSuggestions function from an API endpoint
 *
 * @param {string} endpoint - API endpoint
 * @param {Object} additionalParams - Additional query parameters
 * @returns {Function} - fetchSuggestions function
 */
export function useAutoCompleteFetch(endpoint, additionalParams = {}) {
    return useCallback(
        async (query, signal) => {
            const params = new URLSearchParams({
                query,
                ...additionalParams
            });

            const response = await fetch(`${endpoint}?${params}`, {
                headers: {
                    'Accept': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest'
                },
                signal
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            return data.suggestions || data.results || [];
        },
        [endpoint, JSON.stringify(additionalParams)]
    );
}
