import React, { useState, useRef, useEffect } from 'react';

export default function KnowledgeSearchBar({ query, onSearch, suggestions = [], isLoading }) {
    const [localQuery, setLocalQuery] = useState(query || '');
    const [showSuggestions, setShowSuggestions] = useState(false);
    const [selectedIndex, setSelectedIndex] = useState(-1);
    const inputRef = useRef(null);
    const suggestionsRef = useRef(null);

    useEffect(() => {
        setLocalQuery(query || '');
    }, [query]);

    const handleSubmit = (e) => {
        e.preventDefault();
        if (localQuery.trim()) {
            onSearch(localQuery.trim());
            setShowSuggestions(false);
        }
    };

    const handleChange = (e) => {
        setLocalQuery(e.target.value);
        setShowSuggestions(true);
        setSelectedIndex(-1);
    };

    const handleSuggestionClick = (suggestion) => {
        setLocalQuery(suggestion);
        onSearch(suggestion);
        setShowSuggestions(false);
    };

    const handleKeyDown = (e) => {
        if (!showSuggestions || suggestions.length === 0) return;

        if (e.key === 'ArrowDown') {
            e.preventDefault();
            setSelectedIndex(prev =>
                prev < suggestions.length - 1 ? prev + 1 : prev
            );
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            setSelectedIndex(prev => prev > 0 ? prev - 1 : -1);
        } else if (e.key === 'Enter' && selectedIndex >= 0) {
            e.preventDefault();
            handleSuggestionClick(suggestions[selectedIndex]);
        } else if (e.key === 'Escape') {
            setShowSuggestions(false);
        }
    };

    useEffect(() => {
        const handleClickOutside = (event) => {
            if (
                suggestionsRef.current &&
                !suggestionsRef.current.contains(event.target) &&
                inputRef.current &&
                !inputRef.current.contains(event.target)
            ) {
                setShowSuggestions(false);
            }
        };

        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    return (
        <div className="relative">
            <form onSubmit={handleSubmit}>
                <div className="relative">
                    <input
                        ref={inputRef}
                        type="text"
                        value={localQuery}
                        onChange={handleChange}
                        onKeyDown={handleKeyDown}
                        onFocus={() => setShowSuggestions(true)}
                        placeholder="Search knowledge base... (e.g., 'WireGuard setup', 'React hooks')"
                        className="w-full px-4 py-3 pl-12 pr-24 border border-gray-300 dark:border-gray-600 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                        disabled={isLoading}
                    />
                    <div className="absolute left-4 top-3.5 text-gray-400">
                        🔍
                    </div>
                    <button
                        type="submit"
                        disabled={isLoading || !localQuery.trim()}
                        className="absolute right-2 top-2 px-4 py-1.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
                    >
                        {isLoading ? (
                            <span className="inline-block animate-spin">⏳</span>
                        ) : (
                            'Search'
                        )}
                    </button>
                </div>
            </form>

            {showSuggestions && suggestions.length > 0 && (
                <div
                    ref={suggestionsRef}
                    className="absolute z-10 w-full mt-2 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg shadow-lg max-h-64 overflow-y-auto"
                >
                    {suggestions.map((suggestion, index) => (
                        <button
                            key={index}
                            onClick={() => handleSuggestionClick(suggestion)}
                            className={`w-full px-4 py-2 text-left hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                                index === selectedIndex ? 'bg-blue-50 dark:bg-blue-900/20' : ''
                            }`}
                        >
                            <span className="text-gray-900 dark:text-gray-100">
                                {suggestion}
                            </span>
                        </button>
                    ))}
                </div>
            )}

            <div className="mt-2 text-xs text-gray-500 dark:text-gray-400">
                💡 <strong>Tips:</strong> Keep queries short (2-5 keywords). Use quotes for exact phrases.
                Press ↑/↓ to navigate suggestions.
            </div>
        </div>
    );
}
