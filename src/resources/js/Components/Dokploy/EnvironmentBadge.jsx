import React from 'react';

const environmentColors = {
    dev: {
        bg: 'bg-blue-100 dark:bg-blue-900',
        text: 'text-blue-800 dark:text-blue-200',
        border: 'border-blue-200 dark:border-blue-800',
    },
    qa: {
        bg: 'bg-purple-100 dark:bg-purple-900',
        text: 'text-purple-800 dark:text-purple-200',
        border: 'border-purple-200 dark:border-purple-800',
    },
    uat: {
        bg: 'bg-yellow-100 dark:bg-yellow-900',
        text: 'text-yellow-800 dark:text-yellow-200',
        border: 'border-yellow-200 dark:border-yellow-800',
    },
    prod: {
        bg: 'bg-red-100 dark:bg-red-900',
        text: 'text-red-800 dark:text-red-200',
        border: 'border-red-200 dark:border-red-800',
    },
    staging: {
        bg: 'bg-orange-100 dark:bg-orange-900',
        text: 'text-orange-800 dark:text-orange-200',
        border: 'border-orange-200 dark:border-orange-800',
    },
};

const sizes = {
    xs: 'px-1.5 py-0.5 text-xs',
    sm: 'px-2 py-0.5 text-xs',
    md: 'px-3 py-1 text-sm',
    lg: 'px-4 py-1.5 text-base',
};

export default function EnvironmentBadge({ environment, size = 'md', showBorder = false }) {
    const env = environment?.toLowerCase() || 'unknown';
    const colors = environmentColors[env] || {
        bg: 'bg-gray-100 dark:bg-gray-700',
        text: 'text-gray-800 dark:text-gray-200',
        border: 'border-gray-200 dark:border-gray-600',
    };

    const sizeClass = sizes[size] || sizes.md;
    const borderClass = showBorder ? `border ${colors.border}` : '';

    return (
        <span className={`inline-flex items-center font-medium rounded-full ${colors.bg} ${colors.text} ${sizeClass} ${borderClass}`}>
            {env.toUpperCase()}
        </span>
    );
}
