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
import { formatCents, pcgRoutes } from "@/lib/pcgamer";
import { Head, Link } from "@inertiajs/react";

const TIER_LABELS = {
    entry: "Entry",
    mid: "Mid",
    high: "High",
    enthusiast: "Enthusiast",
};

export default function Index({ auth, presets, filters }) {
    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div className="flex items-center justify-between gap-4">
                    <h2 className="text-xl font-semibold text-gray-800 dark:text-gray-200">
                        Presets AMD AM5
                    </h2>
                    <Link href={pcgRoutes.buildsIndex}>
                        <Button variant="outline" size="sm">
                            Cotações
                        </Button>
                    </Link>
                </div>
            }
        >
            <Head title="PC Gamer — Presets" />

            <div className="mx-auto grid max-w-7xl gap-6 px-4 py-8 sm:grid-cols-2 sm:px-6 lg:px-8">
                {presets.map((preset) => (
                    <Card key={preset.slug}>
                        <CardHeader>
                            <div className="flex items-start justify-between gap-2">
                                <CardTitle className="text-lg">
                                    {preset.name}
                                </CardTitle>
                                <Badge variant="outline">
                                    {TIER_LABELS[preset.tier] ?? preset.tier}
                                </Badge>
                            </div>
                            <CardDescription>
                                {preset.description}
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            <p className="mb-4 text-2xl font-semibold">
                                {formatCents(preset.total_reference_cents)}
                                <span className="ml-2 text-sm font-normal text-muted-foreground">
                                    ref.
                                </span>
                            </p>
                            <ul className="space-y-1 text-sm text-muted-foreground">
                                {(preset.items_json ?? [])
                                    .slice(0, 5)
                                    .map((item, i) => (
                                        <li
                                            key={i}
                                            className="flex justify-between gap-2"
                                        >
                                            <span className="truncate">
                                                {item.label}
                                            </span>
                                            <span className="shrink-0">
                                                {formatCents(
                                                    item.reference_cents,
                                                )}
                                            </span>
                                        </li>
                                    ))}
                                {(preset.items_json?.length ?? 0) > 5 && (
                                    <li className="text-xs">
                                        + {preset.items_json.length - 5} itens…
                                    </li>
                                )}
                            </ul>
                            <p className="mt-3 text-xs text-muted-foreground">
                                Ref. {preset.reference_site} · {preset.platform}
                            </p>
                        </CardContent>
                    </Card>
                ))}
            </div>
        </AuthenticatedLayout>
    );
}
