import React, { useState } from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head } from '@inertiajs/react';
import KnowledgeSearchBar from '@/Components/Archon/KnowledgeSearchBar';
import SearchResults from '@/Components/Archon/SearchResults';
import SourceSelector from '@/Components/Archon/SourceSelector';
import { useKnowledgeSearch } from '@/hooks/useKnowledgeSearch';

export default function KnowledgeBase({ auth, sources = [], initialResults = [] }) {
    const [selectedSource, setSelectedSource] = useState(null);
    const [matchCount, setMatchCount] = useState(10);
    const [returnMode, setReturnMode] = useState('pages');

    const {
        query,
        setQuery,
        results,
        isLoading,
        error,
        search,
        suggestions
    } = useKnowledgeSearch({
        initialResults,
        sourceId: selectedSource,
        matchCount,
        returnMode
    });

    const handleSearch = (searchQuery) => {
        setQuery(searchQuery);
        search(searchQuery);
    };

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <h2 className="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
                    Knowledge Base Search
                </h2>
            }
        >
            <Head title="Knowledge Base" />

            <div className="py-12">
                <div className="max-w-7xl mx-auto sm:px-6 lg:px-8">
                    {/* Search Controls */}
                    <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg mb-6">
                        <div className="p-6">
                            <KnowledgeSearchBar
                                query={query}
                                onSearch={handleSearch}
                                suggestions={suggestions}
                                isLoading={isLoading}
                            />

                            <div className="mt-4 flex flex-wrap gap-4">
                                <SourceSelector
                                    sources={sources}
                                    selectedSource={selectedSource}
                                    onSourceChange={setSelectedSource}
                                />

                                <div className="flex items-center gap-2">
                                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
                                        Results:
                                    </label>
                                    <select
                                        value={matchCount}
                                        onChange={(e) => setMatchCount(Number(e.target.value))}
                                        className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                    >
                                        <option value={5}>5</option>
                                        <option value={10}>10</option>
                                        <option value={20}>20</option>
                                        <option value={50}>50</option>
                                    </select>
                                </div>

                                <div className="flex items-center gap-2">
                                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
                                        Mode:
                                    </label>
                                    <select
                                        value={returnMode}
                                        onChange={(e) => setReturnMode(e.target.value)}
                                        className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
                                    >
                                        <option value="pages">Pages</option>
                                        <option value="chunks">Chunks</option>
                                    </select>
                                </div>
                            </div>

                            {error && (
                                <div className="mt-4 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-md">
                                    <p className="text-sm text-red-800 dark:text-red-200">
                                        {error}
                                    </p>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Search Results */}
                    {isLoading && (
                        <div className="flex justify-center items-center py-12">
                            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
                        </div>
                    )}

                    {!isLoading && results.length > 0 && (
                        <SearchResults
                            results={results}
                            query={query}
                            returnMode={returnMode}
                        />
                    )}

                    {!isLoading && results.length === 0 && query && (
                        <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                            <div className="p-12 text-center">
                                <div className="text-6xl mb-4">🔍</div>
                                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                                    No results found
                                </h3>
                                <p className="text-gray-600 dark:text-gray-400">
                                    Try adjusting your search query or filters
                                </p>
                            </div>
                        </div>
                    )}

                    {!query && (
                        <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                            <div className="p-12 text-center">
                                <div className="text-6xl mb-4">💡</div>
                                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                                    Search the Knowledge Base
                                </h3>
                                <p className="text-gray-600 dark:text-gray-400 mb-4">
                                    Use AI-powered semantic search to find relevant documentation
                                </p>
                                <div className="text-sm text-gray-500 dark:text-gray-500">
                                    <p className="mb-2"><strong>Tips:</strong></p>
                                    <ul className="text-left inline-block space-y-1">
                                        <li>• Keep queries short and focused (2-5 keywords)</li>
                                        <li>• Use source filters to narrow results</li>
                                        <li>• Try "Pages" mode for better context</li>
                                        <li>• Code examples are syntax-highlighted</li>
                                    </ul>
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </AuthenticatedLayout>
    );
}
