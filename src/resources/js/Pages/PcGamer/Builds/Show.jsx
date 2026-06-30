import React, { useState } from "react";
import AuthenticatedLayout from "@/Layouts/AuthenticatedLayout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from "@/components/ui/card";
import {
    BUILD_STATUS_LABELS,
    BUILD_STATUS_TRANSITIONS,
    formatCents,
    pcgRoutes,
} from "@/lib/pcgamer";
import { Head, Link, router, useForm } from "@inertiajs/react";

function StatusTransition({ buildId, currentStatus }) {
    const options = BUILD_STATUS_TRANSITIONS[currentStatus] ?? [];
    const form = useForm({ status: "", notes: "" });

    if (options.length === 0) {
        return null;
    }

    const submit = (e) => {
        e.preventDefault();
        if (!form.data.status) return;
        form.post(pcgRoutes.buildsTransition(buildId), {
            preserveScroll: true,
            onSuccess: () => form.reset(),
        });
    };

    return (
        <Card>
            <CardHeader>
                <CardTitle>Alterar estado</CardTitle>
                <CardDescription>
                    Actual:{" "}
                    {BUILD_STATUS_LABELS[currentStatus] ?? currentStatus}
                </CardDescription>
            </CardHeader>
            <CardContent>
                <form
                    onSubmit={submit}
                    className="flex flex-wrap items-end gap-4"
                >
                    <label className="flex min-w-[180px] flex-col gap-1 text-sm">
                        Novo estado
                        <select
                            className="rounded-md border border-input bg-background px-3 py-2"
                            value={form.data.status}
                            onChange={(e) =>
                                form.setData("status", e.target.value)
                            }
                            required
                        >
                            <option value="">Seleccionar…</option>
                            {options.map((status) => (
                                <option key={status} value={status}>
                                    {BUILD_STATUS_LABELS[status] ?? status}
                                </option>
                            ))}
                        </select>
                    </label>
                    <label className="flex min-w-[240px] flex-1 flex-col gap-1 text-sm">
                        Notas (opcional)
                        <input
                            className="rounded-md border border-input bg-background px-3 py-2"
                            value={form.data.notes}
                            onChange={(e) =>
                                form.setData("notes", e.target.value)
                            }
                            placeholder="Ex.: cliente aprovou por WhatsApp"
                        />
                    </label>
                    <Button type="submit" disabled={form.processing}>
                        Confirmar
                    </Button>
                </form>
            </CardContent>
        </Card>
    );
}

function EventsTimeline({ events }) {
    if (!events?.length) return null;

    const statusEvents = [...events]
        .filter(
            (e) =>
                e.event_type === "status_change" || e.event_type === "created",
        )
        .reverse();

    if (statusEvents.length === 0) return null;

    return (
        <Card>
            <CardHeader>
                <CardTitle>Histórico</CardTitle>
            </CardHeader>
            <CardContent>
                <ul className="space-y-3 text-sm">
                    {statusEvents.map((event, index) => (
                        <li
                            key={index}
                            className="flex flex-wrap gap-2 border-b border-border/40 pb-2 last:border-0"
                        >
                            <span className="text-muted-foreground">
                                {event.created_at
                                    ? new Date(event.created_at).toLocaleString(
                                          "pt-BR",
                                      )
                                    : "—"}
                            </span>
                            {event.from_status && (
                                <Badge variant="outline">
                                    {BUILD_STATUS_LABELS[event.from_status] ??
                                        event.from_status}
                                </Badge>
                            )}
                            {event.to_status && (
                                <>
                                    <span>→</span>
                                    <Badge>
                                        {BUILD_STATUS_LABELS[event.to_status] ??
                                            event.to_status}
                                    </Badge>
                                </>
                            )}
                            {event.notes && (
                                <span className="text-muted-foreground">
                                    {event.notes}
                                </span>
                            )}
                        </li>
                    ))}
                </ul>
            </CardContent>
        </Card>
    );
}

function ItemEditor({ buildId, item, onSaved }) {
    const [cents, setCents] = useState(
        item.unit_cost_cents ? String(item.unit_cost_cents / 100) : "",
    );
    const [saving, setSaving] = useState(false);

    const save = () => {
        const value = Math.round(
            parseFloat(String(cents).replace(",", ".")) * 100,
        );
        if (Number.isNaN(value) || value < 0) return;
        setSaving(true);
        router.put(
            pcgRoutes.buildsItemUpdate(buildId, item.id),
            { unit_cost_cents: value },
            {
                preserveScroll: true,
                onFinish: () => {
                    setSaving(false);
                    onSaved?.();
                },
            },
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
            <Button
                type="button"
                size="sm"
                variant="outline"
                disabled={saving}
                onClick={save}
            >
                {saving ? "…" : "Guardar"}
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
                        <p className="font-mono text-xs text-muted-foreground">
                            {build.code}
                        </p>
                        <h2 className="text-xl font-semibold text-gray-800 dark:text-gray-200">
                            {build.title}
                        </h2>
                    </div>
                    <Badge>
                        {BUILD_STATUS_LABELS[build.status] ?? build.status}
                    </Badge>
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

                <Link
                    href={pcgRoutes.buildsIndex}
                    className="text-sm text-primary hover:underline"
                >
                    ← Voltar à lista
                </Link>

                <div className="grid gap-4 md:grid-cols-3">
                    <Card>
                        <CardHeader className="pb-2">
                            <CardDescription>Custo peças</CardDescription>
                            <CardTitle>
                                {formatCents(build.cost_cents)}
                            </CardTitle>
                        </CardHeader>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardDescription>
                                Cotação cliente ({build.margin_percent}%)
                            </CardDescription>
                            <CardTitle>
                                {formatCents(build.quote_cents)}
                            </CardTitle>
                        </CardHeader>
                    </Card>
                    {comparison && (
                        <Card>
                            <CardHeader className="pb-2">
                                <CardDescription>
                                    Ref. mercado (melhor/slot)
                                </CardDescription>
                                <CardTitle>
                                    {formatCents(
                                        comparison.reference_market_total_cents,
                                    )}
                                </CardTitle>
                            </CardHeader>
                        </Card>
                    )}
                </div>

                <StatusTransition
                    buildId={build.id}
                    currentStatus={build.status}
                />

                <Card>
                    <CardHeader>
                        <CardTitle>Itens da montagem</CardTitle>
                        <CardDescription>
                            Custo unitário em reais (editável)
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[720px] text-left text-sm">
                            <thead>
                                <tr className="border-b text-muted-foreground">
                                    <th className="py-2 pr-4">Categoria</th>
                                    <th className="py-2 pr-4">Label</th>
                                    <th className="py-2 pr-4">Custo (R$)</th>
                                    <th className="py-2 pr-4 text-right">
                                        Total
                                    </th>
                                </tr>
                            </thead>
                            <tbody>
                                {build.items.map((item) => (
                                    <tr
                                        key={item.id}
                                        className="border-b border-border/50"
                                    >
                                        <td className="py-3 pr-4 font-mono text-xs">
                                            {item.category_slug}
                                        </td>
                                        <td className="py-3 pr-4">
                                            {item.label}
                                        </td>
                                        <td className="py-3 pr-4">
                                            <ItemEditor
                                                buildId={build.id}
                                                item={item}
                                            />
                                        </td>
                                        <td className="py-3 pr-4 text-right">
                                            {formatCents(
                                                item.unit_cost_cents *
                                                    item.quantity,
                                            )}
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
                            <CardTitle>
                                Comparativo mercado / Telegram
                            </CardTitle>
                            <CardDescription>
                                Melhor preço por slot vs sua cotação
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="overflow-x-auto">
                            <table className="w-full min-w-[800px] text-left text-sm">
                                <thead>
                                    <tr className="border-b text-muted-foreground">
                                        <th className="py-2 pr-4">Slot</th>
                                        <th className="py-2 pr-4 text-right">
                                            Seu preço
                                        </th>
                                        <th className="py-2 pr-4 text-right">
                                            Mercado
                                        </th>
                                        <th className="py-2 pr-4 text-right">
                                            Δ
                                        </th>
                                        <th className="py-2">Fonte</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {comparison.lines.map((line) => (
                                        <tr
                                            key={line.item_id}
                                            className="border-b border-border/50"
                                        >
                                            <td className="py-2 pr-4">
                                                <div className="font-mono text-xs">
                                                    {line.category_slug}
                                                </div>
                                                <div className="text-muted-foreground">
                                                    {line.label}
                                                </div>
                                            </td>
                                            <td className="py-2 pr-4 text-right">
                                                {formatCents(line.our_cents)}
                                            </td>
                                            <td className="py-2 pr-4 text-right">
                                                {formatCents(
                                                    line.market_best_cents,
                                                )}
                                            </td>
                                            <td
                                                className={`py-2 pr-4 text-right ${line.delta_cents > 0 ? "text-red-600" : line.delta_cents < 0 ? "text-green-600" : ""}`}
                                            >
                                                {line.delta_cents != null
                                                    ? `${line.delta_cents > 0 ? "+" : ""}${formatCents(line.delta_cents)}`
                                                    : "—"}
                                            </td>
                                            <td className="py-2">
                                                {line.market_best_source ?? "—"}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </CardContent>
                    </Card>
                )}

                <EventsTimeline events={build.events} />
            </div>
        </AuthenticatedLayout>
    );
}
