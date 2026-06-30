import React from "react";

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

import { BUILD_STATUS_LABELS, formatCents, pcgRoutes } from "@/lib/pcgamer";

import { Head, Link, router, useForm } from "@inertiajs/react";

export default function Index({
    auth,
    categories,
    components,
    filters,
    flash,
}) {
    const form = useForm({
        category_slug: filters.category ?? categories[0]?.slug ?? "",

        brand: "",

        model: "",

        sku: "",

        notes: "",
    });

    const submit = (e) => {
        e.preventDefault();

        form.post(pcgRoutes.catalogStore, {
            preserveScroll: true,

            onSuccess: () => form.reset("brand", "model", "sku", "notes"),
        });
    };

    const filterCategory = (slug) => {
        router.get(
            pcgRoutes.catalog,

            slug ? { category: slug } : {},

            { preserveState: true, preserveScroll: true },
        );
    };

    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex flex-wrap items-center justify-between gap-4">
                    <h2 className="text-xl font-semibold text-gray-800 dark:text-gray-200">
                        PC Gamer — Catálogo
                    </h2>

                    <div className="flex gap-2">
                        <Link href={pcgRoutes.buildsIndex}>
                            <Button variant="outline" size="sm">
                                Cotações
                            </Button>
                        </Link>

                        <Link href={pcgRoutes.marketPrices}>
                            <Button variant="outline" size="sm">
                                Preços mercado
                            </Button>
                        </Link>
                    </div>
                </div>
            }
        >
            <Head title="PC Gamer — Catálogo" />

            <div className="mx-auto max-w-7xl space-y-6 px-4 py-8 sm:px-6 lg:px-8">
                {flash?.success && (
                    <div className="rounded-md border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800 dark:border-green-800 dark:bg-green-950 dark:text-green-200">
                        {flash.success}
                    </div>
                )}

                <Card>
                    <CardHeader>
                        <CardTitle>Adicionar componente</CardTitle>

                        <CardDescription>
                            Peças reutilizáveis nas cotações
                        </CardDescription>
                    </CardHeader>

                    <CardContent>
                        <form
                            onSubmit={submit}
                            className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"
                        >
                            <label className="flex flex-col gap-1 text-sm">
                                Categoria
                                <select
                                    className="rounded-md border border-input bg-background px-3 py-2"
                                    value={form.data.category_slug}
                                    onChange={(e) =>
                                        form.setData(
                                            "category_slug",

                                            e.target.value,
                                        )
                                    }
                                    required
                                >
                                    {categories.map((cat) => (
                                        <option key={cat.slug} value={cat.slug}>
                                            {cat.name}
                                        </option>
                                    ))}
                                </select>
                            </label>

                            <label className="flex flex-col gap-1 text-sm">
                                Marca
                                <input
                                    className="rounded-md border border-input bg-background px-3 py-2"
                                    value={form.data.brand}
                                    onChange={(e) =>
                                        form.setData("brand", e.target.value)
                                    }
                                />
                            </label>

                            <label className="flex flex-col gap-1 text-sm sm:col-span-2">
                                Modelo
                                <input
                                    className="rounded-md border border-input bg-background px-3 py-2"
                                    value={form.data.model}
                                    onChange={(e) =>
                                        form.setData("model", e.target.value)
                                    }
                                    required
                                />
                            </label>

                            <label className="flex flex-col gap-1 text-sm">
                                SKU
                                <input
                                    className="rounded-md border border-input bg-background px-3 py-2"
                                    value={form.data.sku}
                                    onChange={(e) =>
                                        form.setData("sku", e.target.value)
                                    }
                                />
                            </label>

                            <label className="flex flex-col gap-1 text-sm sm:col-span-2 lg:col-span-3">
                                Notas
                                <input
                                    className="rounded-md border border-input bg-background px-3 py-2"
                                    value={form.data.notes}
                                    onChange={(e) =>
                                        form.setData("notes", e.target.value)
                                    }
                                />
                            </label>

                            <div className="flex items-end">
                                <Button
                                    type="submit"
                                    disabled={form.processing}
                                >
                                    Adicionar
                                </Button>
                            </div>
                        </form>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <div className="flex flex-wrap items-center justify-between gap-4">
                            <div>
                                <CardTitle>Componentes</CardTitle>

                                <CardDescription>
                                    {components.length} registo(s)
                                </CardDescription>
                            </div>

                            <div className="flex flex-wrap gap-2">
                                <Button
                                    type="button"
                                    size="sm"
                                    variant={
                                        !filters.category
                                            ? "default"
                                            : "outline"
                                    }
                                    onClick={() => filterCategory(null)}
                                >
                                    Todas
                                </Button>

                                {categories.map((cat) => (
                                    <Button
                                        key={cat.slug}
                                        type="button"
                                        size="sm"
                                        variant={
                                            filters.category === cat.slug
                                                ? "default"
                                                : "outline"
                                        }
                                        onClick={() => filterCategory(cat.slug)}
                                    >
                                        {cat.name}
                                    </Button>
                                ))}
                            </div>
                        </div>
                    </CardHeader>

                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[640px] text-left text-sm">
                            <thead>
                                <tr className="border-b text-muted-foreground">
                                    <th className="py-2 pr-4">Categoria</th>

                                    <th className="py-2 pr-4">Marca</th>

                                    <th className="py-2 pr-4">Modelo</th>

                                    <th className="py-2 pr-4">SKU</th>
                                </tr>
                            </thead>

                            <tbody>
                                {components.length === 0 && (
                                    <tr>
                                        <td
                                            colSpan={4}
                                            className="py-8 text-center text-muted-foreground"
                                        >
                                            Nenhum componente nesta categoria.
                                        </td>
                                    </tr>
                                )}

                                {components.map((component) => (
                                    <tr
                                        key={component.id}
                                        className="border-b border-border/50"
                                    >
                                        <td className="py-3 pr-4 font-mono text-xs">
                                            {component.category_name ??
                                                component.category_slug}
                                        </td>

                                        <td className="py-3 pr-4">
                                            {component.brand ?? "—"}
                                        </td>

                                        <td className="py-3 pr-4">
                                            {component.model}
                                        </td>

                                        <td className="py-3 pr-4 text-muted-foreground">
                                            {component.sku ?? "—"}
                                        </td>
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
