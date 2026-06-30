import React from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCents, pcgRoutes } from '@/lib/pcgamer';
import { Head, Link } from '@inertiajs/react';

export default function Index({ auth, prices, filters }) {
    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex items-center justify-between gap-4">
                    <h2 className="text-xl font-semibold text-gray-800 dark:text-gray-200">Preços de mercado</h2>
                    <Link href={pcgRoutes.buildsIndex}>
                        <Button variant="outline" size="sm">Cotações</Button>
                    </Link>
                </div>
            }
        >
            <Head title="PC Gamer — Preços" />

            <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
                <Card>
                    <CardHeader>
                        <CardTitle>Últimos registos</CardTitle>
                        {filters.category && (
                            <p className="text-sm text-muted-foreground">Categoria: {filters.category}</p>
                        )}
                    </CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[800px] text-left text-sm">
                            <thead>
                                <tr className="border-b text-muted-foreground">
                                    <th className="py-2 pr-4">Loja</th>
                                    <th className="py-2 pr-4">Categoria</th>
                                    <th className="py-2 pr-4">Produto</th>
                                    <th className="py-2 pr-4 text-right">Preço</th>
                                    <th className="py-2">Fonte</th>
                                </tr>
                            </thead>
                            <tbody>
                                {prices.length === 0 && (
                                    <tr>
                                        <td colSpan={5} className="py-8 text-center text-muted-foreground">
                                            Sem preços. Corra <code className="text-xs">php artisan pcg:fetch-market --all-categories --sync</code>
                                        </td>
                                    </tr>
                                )}
                                {prices.map((row) => (
                                    <tr key={row.id} className="border-b border-border/50">
                                        <td className="py-2 pr-4">{row.retailer_name}</td>
                                        <td className="py-2 pr-4 font-mono text-xs">{row.category_slug}</td>
                                        <td className="py-2 pr-4">
                                            {row.url ? (
                                                <a href={row.url} target="_blank" rel="noreferrer" className="text-primary hover:underline">
                                                    {row.product_name}
                                                </a>
                                            ) : (
                                                row.product_name
                                            )}
                                        </td>
                                        <td className="py-2 pr-4 text-right font-medium">{formatCents(row.price_cents)}</td>
                                        <td className="py-2 text-xs text-muted-foreground">{row.source}</td>
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
