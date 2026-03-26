import React from 'react';
import { Link, router } from '@inertiajs/react';

export default function AuthenticatedLayout({ user, header, children }) {
    const logout = (e) => {
        e.preventDefault();
        router.post('/logout');
    };

    return (
        <div className="min-h-screen bg-gray-100 dark:bg-gray-900">
            <nav className="border-b border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
                <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6 lg:px-8">
                    <div className="flex items-center gap-6">
                        <Link
                            href="/daily-memory"
                            className="text-lg font-semibold text-gray-900 dark:text-gray-100"
                        >
                            Memória diária
                        </Link>
                        <Link
                            href="/dashboard"
                            className="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
                        >
                            Dashboard
                        </Link>
                        <Link
                            href="/archon"
                            className="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
                        >
                            Archon
                        </Link>
                    </div>
                    {user && (
                        <div className="flex items-center gap-4">
                            <span className="text-sm text-gray-600 dark:text-gray-400">{user.name}</span>
                            <button
                                type="button"
                                onClick={logout}
                                className="rounded-md bg-gray-200 px-3 py-1.5 text-sm font-medium text-gray-800 hover:bg-gray-300 dark:bg-gray-700 dark:text-gray-200 dark:hover:bg-gray-600"
                            >
                                Sair
                            </button>
                        </div>
                    )}
                </div>
            </nav>

            {header && (
                <header className="border-b border-gray-200 bg-white shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">{header}</div>
                </header>
            )}

            <main>{children}</main>
        </div>
    );
}
