import React from 'react';

export default function SourceSelector({ sources, selectedSource, onSourceChange }) {
    return (
        <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
                Source:
            </label>
            <select
                value={selectedSource || ''}
                onChange={(e) => onSourceChange(e.target.value || null)}
                className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-gray-200"
            >
                <option value="">All Sources</option>
                {sources.map((source) => (
                    <option key={source.id} value={source.id}>
                        {source.name || source.title || source.id}
                        {source.document_count && ` (${source.document_count} docs)`}
                    </option>
                ))}
            </select>

            {sources.length === 0 && (
                <span className="text-sm text-gray-500 dark:text-gray-400 italic">
                    No sources available
                </span>
            )}
        </div>
    );
}
