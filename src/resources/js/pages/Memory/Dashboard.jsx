import React from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, Link, router, usePage } from '@inertiajs/react';

function formatDate(d) {
    if (!d) {
        return '—';
    }
    return typeof d === 'string' ? d.slice(0, 10) : d;
}

export default function Dashboard({ auth, logs, filters, stats }) {
    const { flash } = usePage().props;

    const submitFilter = (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        router.get('/daily-memory', {
            q: fd.get('q') || '',
            from: fd.get('from') || '',
            to: fd.get('to') || '',
        });
    };

    const rows = logs?.data ?? [];
    const links = logs?.links ?? [];

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="text-2xl font-semibold text-gray-900 dark:text-gray-100">
                            Memória de sessões
                        </h1>
                        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
                            Resumos por dia, pesquisa por texto, projeto ou intervalo de datas.
                        </p>
                    </div>
                    <Link
                        href="/daily-memory/create"
                        className="inline-flex items-center justify-center rounded-md bg-teal-600 px-4 py-2 text-sm font-medium text-white shadow hover:bg-teal-700"
                    >
                        Novo registo
                    </Link>
                </div>
            }
        >
            <Head title="Memória diária" />

            <div className="py-8">
                <div className="mx-auto max-w-7xl space-y-6 px-4 sm:px-6 lg:px-8">
                    {flash?.success && (
                        <div className="rounded-md border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800 dark:border-green-800 dark:bg-green-900/30 dark:text-green-200">
                            {flash.success}
                        </div>
                    )}

                    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                        <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                            <p className="text-sm text-gray-500 dark:text-gray-400">Total de registos</p>
                            <p className="text-2xl font-semibold text-gray-900 dark:text-gray-100">
                                {stats?.total ?? 0}
                            </p>
                        </div>
                        <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                            <p className="text-sm text-gray-500 dark:text-gray-400">Última data registada</p>
                            <p className="text-2xl font-semibold text-gray-900 dark:text-gray-100">
                                {formatDate(stats?.last_occurred_on)}
                            </p>
                        </div>
                    </div>

                    <form
                        onSubmit={submitFilter}
                        className="flex flex-col gap-4 rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800 md:flex-row md:flex-wrap md:items-end"
                    >
                        <div className="min-w-[200px] flex-1">
                            <label htmlFor="q" className="block text-xs font-medium text-gray-700 dark:text-gray-300">
                                Pesquisa
                            </label>
                            <input
                                id="q"
                                name="q"
                                type="search"
                                defaultValue={filters?.q ?? ''}
                                placeholder="Resumo, título, etiquetas"
                                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                            />
                        </div>
                        <div>
                            <label htmlFor="from" className="block text-xs font-medium text-gray-700 dark:text-gray-300">
                                De
                            </label>
                            <input
                                id="from"
                                name="from"
                                type="date"
                                defaultValue={filters?.from ?? ''}
                                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                            />
                        </div>
                        <div>
                            <label htmlFor="to" className="block text-xs font-medium text-gray-700 dark:text-gray-300">
                                Até
                            </label>
                            <input
                                id="to"
                                name="to"
                                type="date"
                                defaultValue={filters?.to ?? ''}
                                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                            />
                        </div>
                        <div className="flex gap-2">
                            <button
                                type="submit"
                                className="rounded-md bg-gray-800 px-4 py-2 text-sm font-medium text-white hover:bg-gray-900 dark:bg-gray-600 dark:hover:bg-gray-500"
                            >
                                Filtrar
                            </button>
                            <Link
                                href="/daily-memory"
                                className="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                            >
                                Limpar
                            </Link>
                        </div>
                    </form>

                    <div className="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm dark:border-gray-700 dark:bg-gray-800">
                        <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                            <thead className="bg-gray-50 dark:bg-gray-900/50">
                                <tr>
                                    <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                                        Data
                                    </th>
                                    <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                                        Título
                                    </th>
                                    <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                                        Projetos
                                    </th>
                                    <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                                        Ações
                                    </th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                                {rows.length === 0 ? (
                                    <tr>
                                        <td colSpan={4} className="px-4 py-8 text-center text-sm text-gray-500 dark:text-gray-400">
                                            Sem registos.{' '}
                                            <Link href="/daily-memory/create" className="text-teal-600 hover:underline">
                                                Criar o primeiro
                                            </Link>
                                            .
                                        </td>
                                    </tr>
                                ) : (
                                    rows.map((row) => (
                                        <tr key={row.id} className="hover:bg-gray-50 dark:hover:bg-gray-900/40">
                                            <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                                                {formatDate(row.occurred_on)}
                                            </td>
                                            <td className="max-w-md px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                                                {row.title || '(sem título)'}
                                            </td>
                                            <td className="max-w-xs px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                                                {Array.isArray(row.project_tags) && row.project_tags.length
                                                    ? row.project_tags.join(', ')
                                                    : '—'}
                                            </td>
                                            <td className="whitespace-nowrap px-4 py-3 text-right text-sm">
                                                <Link
                                                    href={`/daily-memory/${row.id}`}
                                                    className="text-teal-600 hover:underline dark:text-teal-400"
                                                >
                                                    Ver
                                                </Link>
                                            </td>
                                        </tr>
                                    ))
                                )}
                            </tbody>
                        </table>
                    </div>

                    {links.length > 3 && (
                        <nav className="flex flex-wrap justify-center gap-1" aria-label="Paginação">
                            {links.map((link, i) => {
                                if (!link.url) {
                                    return (
                                        <span
                                            key={i}
                                            className="inline-flex min-w-[2rem] items-center justify-center rounded border border-gray-200 dark:border-gray-700 px-2 py-1 text-sm text-gray-400 dark:text-gray-500"
                                            dangerouslySetInnerHTML={{ __html: link.label }}
                                        />
                                    );
                                }
                                return (
                                    <Link
                                        key={i}
                                        href={link.url}
                                        preserveScroll
                                        className={`inline-flex min-w-[2rem] items-center justify-center rounded border px-2 py-1 text-sm ${
                                            link.active
                                                ? 'border-teal-600 bg-teal-600 text-white'
                                                : 'border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800'
                                        }`}
                                        dangerouslySetInnerHTML={{ __html: link.label }}
                                    />
                                );
                            })}
                        </nav>
                    )}
                </div>
            </div>
        </AuthenticatedLayout>
    );
}
