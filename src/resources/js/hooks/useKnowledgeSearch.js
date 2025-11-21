import { useState, useEffect, useCallback, useRef } from 'react';
import { router } from '@inertiajs/react';
import { debounce } from 'lodash';

/**
 * Custom hook for knowledge base search with debouncing and autocomplete
 *
 * @param {Object} options - Configuration options
 * @param {Array} options.initialResults - Initial search results
 * @param {string} options.sourceId - Filter by source ID
 * @param {number} options.matchCount - Number of results to return
 * @param {string} options.returnMode - 'pages' or 'chunks'
 * @param {number} options.debounceMs - Debounce delay in ms (default: 300)
 * @returns {Object} - { query, setQuery, results, isLoading, error, search, suggestions }
 */
export function useKnowledgeSearch({
    initialResults = [],
    sourceId = null,
    matchCount = 10,
    returnMode = 'pages',
    debounceMs = 300
}) {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState(initialResults);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState(null);
    const [suggestions, setSuggestions] = useState([]);
    const abortControllerRef = useRef(null);

    // Debounced search function
    const debouncedSearch = useCallback(
        debounce(async (searchQuery) => {
            if (!searchQuery.trim()) {
                setResults([]);
                setSuggestions([]);
                return;
            }

            // Abort previous request
            if (abortControllerRef.current) {
                abortControllerRef.current.abort();
            }

            abortControllerRef.current = new AbortController();

            setIsLoading(true);
            setError(null);

            try {
                const response = await fetch('/archon/knowledge/search', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest',
                        'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content
                    },
                    body: JSON.stringify({
                        query: searchQuery,
                        source_id: sourceId,
                        match_count: matchCount,
                        return_mode: returnMode
                    }),
                    signal: abortControllerRef.current.signal
                });

                if (!response.ok) {
                    throw new Error(`Search failed: ${response.status}`);
                }

                const data = await response.json();
                setResults(data.results || []);
            } catch (err) {
                if (err.name !== 'AbortError') {
                    setError(err.message);
                    console.error('Search error:', err);
                }
            } finally {
                setIsLoading(false);
            }
        }, debounceMs),
        [sourceId, matchCount, returnMode, debounceMs]
    );

    // Fetch autocomplete suggestions
    const fetchSuggestions = useCallback(
        debounce(async (searchQuery) => {
            if (!searchQuery.trim() || searchQuery.length < 2) {
                setSuggestions([]);
                return;
            }

            try {
                const response = await fetch('/archon/knowledge/suggestions', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest',
                        'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content
                    },
                    body: JSON.stringify({
                        query: searchQuery,
                        limit: 5
                    })
                });

                if (response.ok) {
                    const data = await response.json();
                    setSuggestions(data.suggestions || []);
                }
            } catch (err) {
                console.error('Suggestions error:', err);
            }
        }, 300),
        []
    );

    // Update suggestions when query changes
    useEffect(() => {
        fetchSuggestions(query);
    }, [query, fetchSuggestions]);

    // Manual search function
    const search = useCallback((searchQuery) => {
        debouncedSearch(searchQuery);
    }, [debouncedSearch]);

    // Cleanup on unmount
    useEffect(() => {
        return () => {
            if (abortControllerRef.current) {
                abortControllerRef.current.abort();
            }
            debouncedSearch.cancel();
            fetchSuggestions.cancel();
        };
    }, [debouncedSearch, fetchSuggestions]);

    return {
        query,
        setQuery,
        results,
        isLoading,
        error,
        search,
        suggestions
    };
}
