import React from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { BUILD_STATUS_LABELS, formatCents, pcgRoutes } from '@/lib/pcgamer';
import { Head, Link, useForm } from '@inertiajs/react';

export default function Index({ auth, builds, filters, flash }) {
    const form = useForm({
        title: '',
        customer_name: '',
        margin_percent: 15,
    });

    const createBuild = (e) => {
        e.preventDefault();
        form.post(pcgRoutes.buildsStore, {
            preserveScroll: true,
            onSuccess: () => form.reset('title', 'customer_name'),
        });
    };

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex flex-wrap items-center justify-between gap-4">
                    <h2 className="text-xl font-semibold leading-tight text-gray-800 dark:text-gray-200">
                        PC Gamer — Cotações
                    </h2>
                    <div className="flex gap-2">
                        <Link href={pcgRoutes.presets}>
                            <Button variant="outline" size="sm">Presets</Button>
                        </Link>
                        <Link href={pcgRoutes.marketPrices}>
                            <Button variant="outline" size="sm">Preços mercado</Button>
                        </Link>
                    </div>
                </div>
            }
        >
            <Head title="PC Gamer — Cotações" />

            <div className="mx-auto max-w-7xl space-y-6 px-4 py-8 sm:px-6 lg:px-8">
                {flash?.success && (
                    <div className="rounded-md border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800 dark:border-green-800 dark:bg-green-950 dark:text-green-200">
                        {flash.success}
                    </div>
                )}

                <Card>
                    <CardHeader>
                        <CardTitle>Nova montagem</CardTitle>
                        <CardDescription>Template AMD com 10 slots de peças</CardDescription>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={createBuild} className="flex flex-wrap items-end gap-4">
                            <label className="flex min-w-[200px] flex-1 flex-col gap-1 text-sm">
                                Título
                                <input
                                    className="rounded-md border border-input bg-background px-3 py-2"
                                    value={form.data.title}
                                    onChange={(e) => form.setData('title', e.target.value)}
                                    required
                                />
                            </label>
                            <label className="flex min-w-[160px] flex-col gap-1 text-sm">
                                Cliente
                                <input
                                    className="rounded-md border border-input bg-background px-3 py-2"
                                    value={form.data.customer_name}
                                    onChange={(e) => form.setData('customer_name', e.target.value)}
                                />
                            </label>
                            <label className="flex w-28 flex-col gap-1 text-sm">
                                Margem %
                                <input
                                    type="number"
                                    min="0"
                                    max="100"
                                    className="rounded-md border border-input bg-background px-3 py-2"
                                    value={form.data.margin_percent}
                                    onChange={(e) => form.setData('margin_percent', Number(e.target.value))}
                                />
                            </label>
                            <Button type="submit" disabled={form.processing}>
                                Criar
                            </Button>
                        </form>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>Montagens</CardTitle>
                        {filters.status && (
                            <CardDescription>Filtro: {BUILD_STATUS_LABELS[filters.status] ?? filters.status}</CardDescription>
                        )}
                    </CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[640px] text-left text-sm">
                            <thead>
                                <tr className="border-b text-muted-foreground">
                                    <th className="py-2 pr-4">Código</th>
                                    <th className="py-2 pr-4">Título</th>
                                    <th className="py-2 pr-4">Estado</th>
                                    <th className="py-2 pr-4 text-right">Custo</th>
                                    <th className="py-2 pr-4 text-right">Cliente</th>
                                    <th className="py-2">Itens</th>
                                </tr>
                            </thead>
                            <tbody>
                                {builds.length === 0 && (
                                    <tr>
                                        <td colSpan={6} className="py-8 text-center text-muted-foreground">
                                            Nenhuma montagem ainda.
                                        </td>
                                    </tr>
                                )}
                                {builds.map((build) => (
                                    <tr key={build.id} className="border-b border-border/50 hover:bg-muted/30">
                                        <td className="py-3 pr-4 font-mono text-xs">
                                            <Link
                                                href={pcgRoutes.buildsShow(build.id)}
                                                className="text-primary hover:underline"
                                            >
                                                {build.code}
                                            </Link>
                                        </td>
                                        <td className="py-3 pr-4">{build.title}</td>
                                        <td className="py-3 pr-4">
                                            <Badge variant="secondary">
                                                {BUILD_STATUS_LABELS[build.status] ?? build.status}
                                            </Badge>
                                        </td>
                                        <td className="py-3 pr-4 text-right">{formatCents(build.cost_cents)}</td>
                                        <td className="py-3 pr-4 text-right font-medium">{formatCents(build.quote_cents)}</td>
                                        <td className="py-3">{build.item_count}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>
            </div>
        </AuthenticatedLayout>
    );
}
