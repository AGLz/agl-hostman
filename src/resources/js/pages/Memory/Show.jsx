import React from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, Link, router, usePage } from '@inertiajs/react';

function formatDate(d) {
    if (!d) {
        return '—';
    }
    return typeof d === 'string' ? d.slice(0, 10) : d;
}

export default function Show({ auth, log }) {
    const { flash } = usePage().props;

    const destroy = () => {
        if (!confirm('Eliminar este registo?')) {
            return;
        }
        router.delete(`/daily-memory/${log.id}`);
    };

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div>
                        <h1 className="text-2xl font-semibold text-gray-900 dark:text-gray-100">
                            {log.title || 'Registo diário'}
                        </h1>
                        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
                            {formatDate(log.occurred_on)} · origem: {log.source || 'manual'}
                        </p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        <Link
                            href="/daily-memory"
                            className="rounded-md border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                        >
                            Lista
                        </Link>
                        <Link
                            href={`/daily-memory/${log.id}/edit`}
                            className="rounded-md bg-teal-600 px-3 py-2 text-sm font-medium text-white hover:bg-teal-700"
                        >
                            Editar
                        </Link>
                        <button
                            type="button"
                            onClick={destroy}
                            className="rounded-md border border-red-300 px-3 py-2 text-sm font-medium text-red-700 hover:bg-red-50 dark:border-red-800 dark:text-red-300 dark:hover:bg-red-900/30"
                        >
                            Eliminar
                        </button>
                    </div>
                </div>
            }
        >
            <Head title="Registo — Memória" />

            <div className="py-8">
                <div className="mx-auto max-w-3xl space-y-6 px-4 sm:px-6 lg:px-8">
                    {flash?.success && (
                        <div className="rounded-md border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800 dark:border-green-800 dark:bg-green-900/30 dark:text-green-200">
                            {flash.success}
                        </div>
                    )}

                    <div className="flex flex-wrap gap-2">
                        {Array.isArray(log.project_tags) &&
                            log.project_tags.map((tag) => (
                                <span
                                    key={tag}
                                    className="rounded-full bg-teal-100 px-3 py-1 text-xs font-medium text-teal-800 dark:bg-teal-900/40 dark:text-teal-200"
                                >
                                    {tag}
                                </span>
                            ))}
                        {Array.isArray(log.topics) &&
                            log.topics.map((t) => (
                                <span
                                    key={t}
                                    className="rounded-full bg-gray-200 px-3 py-1 text-xs font-medium text-gray-800 dark:bg-gray-700 dark:text-gray-200"
                                >
                                    {t}
                                </span>
                            ))}
                    </div>

                    <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">
                            Resumo
                        </h2>
                        <pre className="whitespace-pre-wrap font-sans text-sm leading-relaxed text-gray-900 dark:text-gray-100">
                            {log.summary}
                        </pre>
                    </div>
                </div>
            </div>
        </AuthenticatedLayout>
    );
}
