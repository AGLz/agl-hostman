import React, { useState } from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { BUILD_STATUS_LABELS, formatCents, pcgRoutes } from '@/lib/pcgamer';
import { Head, Link, router } from '@inertiajs/react';

function ItemEditor({ buildId, item, onSaved }) {
    const [cents, setCents] = useState(item.unit_cost_cents ? String(item.unit_cost_cents / 100) : '');
    const [saving, setSaving] = useState(false);

    const save = () => {
        const value = Math.round(parseFloat(String(cents).replace(',', '.')) * 100);
        if (Number.isNaN(value) || value < 0) return;
        setSaving(true);
        router.put(
            pcgRoutes.buildsItemUpdate(buildId, item.id),
            { unit_cost_cents: value },
            { preserveScroll: true, onFinish: () => { setSaving(false); onSaved?.(); } },
        );
    };

    return (
        <div className="flex items-center gap-2">
            <input
                type="text"
                inputMode="decimal"
                placeholder="0,00"
                className="w-24 rounded-md border border-input bg-background px-2 py-1 text-sm"
                value={cents}
                onChange={(e) => setCents(e.target.value)}
            />
            <Button type="button" size="sm" variant="outline" disabled={saving} onClick={save}>
                {saving ? '…' : 'Guardar'}
            </Button>
        </div>
    );
}

export default function Show({ auth, build, comparison, flash }) {
    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex flex-wrap items-center justify-between gap-4">
                    <div>
                        <p className="font-mono text-xs text-muted-foreground">{build.code}</p>
                        <h2 className="text-xl font-semibold text-gray-800 dark:text-gray-200">{build.title}</h2>
                    </div>
                    <Badge>{BUILD_STATUS_LABELS[build.status] ?? build.status}</Badge>
                </div>
            }
        >
            <Head title={`${build.code} — PC Gamer`} />

            <div className="mx-auto max-w-7xl space-y-6 px-4 py-8 sm:px-6 lg:px-8">
                {flash?.success && (
                    <div className="rounded-md border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800">
                        {flash.success}
                    </div>
                )}

                <Link href={pcgRoutes.buildsIndex} className="text-sm text-primary hover:underline">
                    ← Voltar à lista
                </Link>

                <div className="grid gap-4 md:grid-cols-3">
                    <Card>
                        <CardHeader className="pb-2">
                            <CardDescription>Custo peças</CardDescription>
                            <CardTitle>{formatCents(build.cost_cents)}</CardTitle>
                        </CardHeader>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardDescription>Cotação cliente ({build.margin_percent}%)</CardDescription>
                            <CardTitle>{formatCents(build.quote_cents)}</CardTitle>
                        </CardHeader>
                    </Card>
                    {comparison && (
                        <Card>
                            <CardHeader className="pb-2">
                                <CardDescription>Ref. mercado (melhor/slot)</CardDescription>
                                <CardTitle>{formatCents(comparison.reference_market_total_cents)}</CardTitle>
                            </CardHeader>
                        </Card>
                    )}
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Itens da montagem</CardTitle>
                        <CardDescription>Custo unitário em reais (editável)</CardDescription>
                    </CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[720px] text-left text-sm">
                            <thead>
                                <tr className="border-b text-muted-foreground">
                                    <th className="py-2 pr-4">Categoria</th>
                                    <th className="py-2 pr-4">Label</th>
                                    <th className="py-2 pr-4">Custo (R$)</th>
                                    <th className="py-2 pr-4 text-right">Total</th>
                                </tr>
                            </thead>
                            <tbody>
                                {build.items.map((item) => (
                                    <tr key={item.id} className="border-b border-border/50">
                                        <td className="py-3 pr-4 font-mono text-xs">{item.category_slug}</td>
                                        <td className="py-3 pr-4">{item.label}</td>
                                        <td className="py-3 pr-4">
                                            <ItemEditor buildId={build.id} item={item} />
                                        </td>
                                        <td className="py-3 pr-4 text-right">
                                            {formatCents(item.unit_cost_cents * item.quantity)}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>

                {comparison && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Comparativo mercado / Telegram</CardTitle>
                            <CardDescription>Melhor preço por slot vs sua cotação</CardDescription>
                        </CardHeader>
                        <CardContent className="overflow-x-auto">
                            <table className="w-full min-w-[800px] text-left text-sm">
                                <thead>
                                    <tr className="border-b text-muted-foreground">
                                        <th className="py-2 pr-4">Slot</th>
                                        <th className="py-2 pr-4 text-right">Seu preço</th>
                                        <th className="py-2 pr-4 text-right">Mercado</th>
                                        <th className="py-2 pr-4 text-right">Δ</th>
                                        <th className="py-2">Fonte</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {comparison.lines.map((line) => (
                                        <tr key={line.item_id} className="border-b border-border/50">
                                            <td className="py-2 pr-4">
                                                <div className="font-mono text-xs">{line.category_slug}</div>
                                                <div className="text-muted-foreground">{line.label}</div>
                                            </td>
                                            <td className="py-2 pr-4 text-right">{formatCents(line.our_cents)}</td>
                                            <td className="py-2 pr-4 text-right">{formatCents(line.market_best_cents)}</td>
                                            <td className={`py-2 pr-4 text-right ${line.delta_cents > 0 ? 'text-red-600' : line.delta_cents < 0 ? 'text-green-600' : ''}`}>
                                                {line.delta_cents != null
                                                    ? `${line.delta_cents > 0 ? '+' : ''}${formatCents(line.delta_cents)}`
                                                    : '—'}
                                            </td>
                                            <td className="py-2">{line.market_best_source ?? '—'}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </CardContent>
                    </Card>
                )}
            </div>
        </AuthenticatedLayout>
    );
}
