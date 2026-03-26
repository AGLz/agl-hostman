import React from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head, Link, useForm } from '@inertiajs/react';

function tagsToString(val) {
    if (val == null) {
        return '';
    }
    if (Array.isArray(val)) {
        return val.join(', ');
    }
    return String(val);
}

export default function Edit({ auth, log }) {
    const { data, setData, put, processing, errors } = useForm({
        occurred_on: log.occurred_on ? String(log.occurred_on).slice(0, 10) : '',
        title: log.title ?? '',
        summary: log.summary ?? '',
        topics: tagsToString(log.topics),
        project_tags: tagsToString(log.project_tags),
        source: log.source ?? 'manual',
    });

    const submit = (e) => {
        e.preventDefault();
        put(`/daily-memory/${log.id}`);
    };

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div>
                    <h1 className="text-2xl font-semibold text-gray-900 dark:text-gray-100">Editar registo</h1>
                    <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">Atualiza o resumo ou as etiquetas.</p>
                </div>
            }
        >
            <Head title="Editar — Memória" />

            <div className="py-8">
                <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
                    <form onSubmit={submit} className="space-y-6 rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                        <div>
                            <label htmlFor="occurred_on" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                                Data *
                            </label>
                            <input
                                id="occurred_on"
                                type="date"
                                value={data.occurred_on}
                                onChange={(e) => setData('occurred_on', e.target.value)}
                                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                                required
                            />
                            {errors.occurred_on && (
                                <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.occurred_on}</p>
                            )}
                        </div>

                        <div>
                            <label htmlFor="title" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                                Título (opcional)
                            </label>
                            <input
                                id="title"
                                type="text"
                                value={data.title}
                                onChange={(e) => setData('title', e.target.value)}
                                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                                maxLength={255}
                            />
                            {errors.title && <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.title}</p>}
                        </div>

                        <div>
                            <label htmlFor="summary" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                                Resumo *
                            </label>
                            <textarea
                                id="summary"
                                value={data.summary}
                                onChange={(e) => setData('summary', e.target.value)}
                                rows={12}
                                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 font-mono text-sm dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                                required
                            />
                            {errors.summary && (
                                <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.summary}</p>
                            )}
                        </div>

                        <div>
                            <label htmlFor="topics" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                                Tópicos
                            </label>
                            <input
                                id="topics"
                                type="text"
                                value={data.topics}
                                onChange={(e) => setData('topics', e.target.value)}
                                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                            />
                            {errors.topics && <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.topics}</p>}
                        </div>

                        <div>
                            <label htmlFor="project_tags" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                                Projetos / etiquetas
                            </label>
                            <input
                                id="project_tags"
                                type="text"
                                value={data.project_tags}
                                onChange={(e) => setData('project_tags', e.target.value)}
                                className="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                            />
                            {errors.project_tags && (
                                <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.project_tags}</p>
                            )}
                        </div>

                        <div className="flex items-center justify-end gap-3 border-t border-gray-200 pt-6 dark:border-gray-700">
                            <Link
                                href={`/daily-memory/${log.id}`}
                                className="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                            >
                                Cancelar
                            </Link>
                            <button
                                type="submit"
                                disabled={processing}
                                className="rounded-md bg-teal-600 px-4 py-2 text-sm font-medium text-white hover:bg-teal-700 disabled:opacity-50"
                            >
                                {processing ? 'A guardar...' : 'Guardar'}
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </AuthenticatedLayout>
    );
}
