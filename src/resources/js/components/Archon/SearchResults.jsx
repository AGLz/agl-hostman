import React, { useState } from 'react';
import { router } from '@inertiajs/react';
import CodeExampleCard from './CodeExampleCard';

export default function SearchResults({ results, query, returnMode }) {
    const [expandedPages, setExpandedPages] = useState(new Set());

    const togglePage = (pageId) => {
        setExpandedPages(prev => {
            const newSet = new Set(prev);
            if (newSet.has(pageId)) {
                newSet.delete(pageId);
            } else {
                newSet.add(pageId);
            }
            return newSet;
        });
    };

    const highlightText = (text, query) => {
        if (!query) return text;

        const parts = text.split(new RegExp(`(${query})`, 'gi'));
        return parts.map((part, index) =>
            part.toLowerCase() === query.toLowerCase() ? (
                <mark key={index} className="bg-yellow-200 dark:bg-yellow-600 px-1 rounded">
                    {part}
                </mark>
            ) : (
                part
            )
        );
    };

    const loadFullPage = (pageId) => {
        router.post('/archon/knowledge/page', { page_id: pageId });
    };

    if (returnMode === 'chunks') {
        return (
            <div className="space-y-4">
                {results.map((chunk, index) => (
                    <div
                        key={index}
                        className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg"
                    >
                        <div className="p-6">
                            <div className="flex justify-between items-start mb-4">
                                <div className="flex-1">
                                    <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                                        {chunk.metadata?.title || 'Untitled'}
                                    </h3>
                                    {chunk.metadata?.url && (
                                        <a
                                            href={chunk.metadata.url}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            className="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
                                        >
                                            {chunk.metadata.url}
                                        </a>
                                    )}
                                </div>
                                <span className="px-3 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-200 text-sm font-medium rounded-full">
                                    {Math.round((chunk.similarity || 0) * 100)}% match
                                </span>
                            </div>

                            <div className="prose dark:prose-invert max-w-none">
                                <p className="text-gray-700 dark:text-gray-300">
                                    {highlightText(chunk.content, query)}
                                </p>
                            </div>

                            {chunk.metadata?.section_title && (
                                <div className="mt-4 text-sm text-gray-500 dark:text-gray-400">
                                    Section: {chunk.metadata.section_title}
                                </div>
                            )}
                        </div>
                    </div>
                ))}
            </div>
        );
    }

    // Pages mode
    return (
        <div className="space-y-4">
            {results.map((page, index) => {
                const isExpanded = expandedPages.has(page.page_id);

                return (
                    <div
                        key={index}
                        className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg"
                    >
                        <div className="p-6">
                            <div className="flex justify-between items-start mb-4">
                                <div className="flex-1">
                                    <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                                        {page.title || 'Untitled'}
                                    </h3>
                                    {page.url && (
                                        <a
                                            href={page.url}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            className="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
                                        >
                                            {page.url}
                                        </a>
                                    )}
                                </div>
                                <div className="flex gap-2 items-center">
                                    <span className="px-3 py-1 bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-200 text-sm font-medium rounded-full">
                                        {page.chunk_matches || 0} matches
                                    </span>
                                    {page.word_count && (
                                        <span className="text-sm text-gray-500 dark:text-gray-400">
                                            {page.word_count.toLocaleString()} words
                                        </span>
                                    )}
                                </div>
                            </div>

                            <div className="prose dark:prose-invert max-w-none mb-4">
                                <p className="text-gray-700 dark:text-gray-300">
                                    {highlightText(page.preview, query)}
                                </p>
                            </div>

                            <div className="flex gap-2">
                                <button
                                    onClick={() => togglePage(page.page_id)}
                                    className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors text-sm"
                                >
                                    {isExpanded ? 'Hide Full Page' : 'Read Full Page'}
                                </button>
                                {page.metadata?.source_id && (
                                    <span className="px-3 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-md text-sm">
                                        Source: {page.metadata.source_name || page.metadata.source_id}
                                    </span>
                                )}
                            </div>

                            {isExpanded && page.full_content && (
                                <div className="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
                                    <div className="prose dark:prose-invert max-w-none">
                                        <div
                                            dangerouslySetInnerHTML={{
                                                __html: page.full_content
                                                    .replace(
                                                        new RegExp(`(${query})`, 'gi'),
                                                        '<mark class="bg-yellow-200 dark:bg-yellow-600 px-1 rounded">$1</mark>'
                                                    )
                                            }}
                                        />
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                );
            })}
        </div>
    );
}
