import React, { useState } from 'react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus, vs } from 'react-syntax-highlighter/dist/esm/styles/prism';

export default function CodeExampleCard({ example, query }) {
    const [copied, setCopied] = useState(false);
    const [isDark, setIsDark] = useState(
        window.matchMedia('(prefers-color-scheme: dark)').matches
    );

    const copyToClipboard = async () => {
        try {
            await navigator.clipboard.writeText(example.content);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        } catch (err) {
            console.error('Failed to copy:', err);
        }
    };

    const getLanguage = () => {
        if (example.metadata?.language) {
            return example.metadata.language.toLowerCase();
        }

        // Detect from file extension
        if (example.metadata?.file_path) {
            const ext = example.metadata.file_path.split('.').pop();
            const extMap = {
                'js': 'javascript',
                'jsx': 'jsx',
                'ts': 'typescript',
                'tsx': 'tsx',
                'py': 'python',
                'php': 'php',
                'rb': 'ruby',
                'go': 'go',
                'rs': 'rust',
                'java': 'java',
                'cpp': 'cpp',
                'c': 'c',
                'sh': 'bash',
                'yml': 'yaml',
                'yaml': 'yaml',
                'json': 'json',
                'xml': 'xml',
                'html': 'html',
                'css': 'css',
                'scss': 'scss',
                'sql': 'sql'
            };
            return extMap[ext] || 'text';
        }

        return 'text';
    };

    const language = getLanguage();

    return (
        <div className="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
            <div className="p-6">
                <div className="flex justify-between items-start mb-4">
                    <div className="flex-1">
                        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                            {example.metadata?.title || 'Code Example'}
                        </h3>
                        {example.summary && (
                            <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">
                                {example.summary}
                            </p>
                        )}
                        {example.metadata?.file_path && (
                            <code className="text-xs text-blue-600 dark:text-blue-400">
                                {example.metadata.file_path}
                            </code>
                        )}
                    </div>
                    <div className="flex gap-2 items-center">
                        <span className="px-3 py-1 bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-200 text-xs font-medium rounded-full">
                            {language}
                        </span>
                        {example.similarity && (
                            <span className="px-3 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-200 text-xs font-medium rounded-full">
                                {Math.round(example.similarity * 100)}% match
                            </span>
                        )}
                    </div>
                </div>

                <div className="relative">
                    <button
                        onClick={copyToClipboard}
                        className="absolute top-2 right-2 px-3 py-1 bg-gray-700 hover:bg-gray-600 text-white text-xs rounded transition-colors z-10"
                        title="Copy code"
                    >
                        {copied ? '✓ Copied!' : '📋 Copy'}
                    </button>

                    <div className="rounded-lg overflow-hidden">
                        <SyntaxHighlighter
                            language={language}
                            style={isDark ? vscDarkPlus : vs}
                            showLineNumbers={true}
                            wrapLines={true}
                            customStyle={{
                                margin: 0,
                                borderRadius: '0.5rem',
                                fontSize: '0.875rem'
                            }}
                        >
                            {example.content}
                        </SyntaxHighlighter>
                    </div>
                </div>

                {example.metadata?.url && (
                    <div className="mt-4">
                        <a
                            href={example.metadata.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
                        >
                            View source →
                        </a>
                    </div>
                )}
            </div>
        </div>
    );
}
