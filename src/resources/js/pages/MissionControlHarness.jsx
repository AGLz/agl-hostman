import React, { useCallback, useEffect, useState } from "react";
import {
    Activity,
    Gauge,
    Layers,
    Loader2,
    RefreshCw,
    Route,
    Wallet,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
    HARNESS_POLL_INTERVAL_MS,
    actionBadgeClass,
    fetchHarnessSnapshot,
    formatTierSummary,
} from "@/lib/harness";

function MetricTile({ label, value, sub }) {
    return (
        <div className="rounded-lg border border-white/5 bg-white/[0.03] p-4">
            <p className="text-xs text-white/40">{label}</p>
            <p className="text-xl font-semibold text-white mt-1">{value}</p>
            {sub && <p className="text-[11px] text-white/30 mt-1">{sub}</p>}
        </div>
    );
}

export default function MissionControlHarness() {
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const load = useCallback(async () => {
        try {
            setError(null);
            const snapshot = await fetchHarnessSnapshot();
            setData(snapshot);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        load();
        const timer = setInterval(load, HARNESS_POLL_INTERVAL_MS);
        return () => clearInterval(timer);
    }, [load]);

    const governor = data?.governor ?? {};
    const tiers = governor.tiers ?? {};

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between gap-4 flex-wrap">
                <div>
                    <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Route className="w-6 h-6 text-violet-400" />
                        Harness Router
                    </h1>
                    <p className="text-sm text-white/40 mt-1">
                        LiteLLM spend · tiers T3–T5 · Hermes mode · fila bd /
                        Agent-OS
                    </p>
                </div>
                <Button
                    variant="outline"
                    size="sm"
                    className="bg-white/5 border-white/10 text-white/70"
                    onClick={load}
                    disabled={loading}
                >
                    <RefreshCw
                        className={`w-3.5 h-3.5 mr-1.5 ${loading ? "animate-spin" : ""}`}
                    />
                    Atualizar
                </Button>
            </div>

            {loading && !data && (
                <Card className="bg-white/[0.02] border-white/5 flex items-center justify-center py-16">
                    <Loader2 className="w-6 h-6 animate-spin text-white/40" />
                </Card>
            )}

            {error && (
                <Card className="bg-red-500/10 border-red-500/20">
                    <CardHeader>
                        <CardTitle className="text-red-300 text-sm">
                            Snapshot indisponível
                        </CardTitle>
                        <CardDescription className="text-red-200/70">
                            {error}
                        </CardDescription>
                    </CardHeader>
                </Card>
            )}

            {data && (
                <>
                    <div className="flex flex-wrap items-center gap-2">
                        <Badge className={actionBadgeClass(governor.action)}>
                            Governor: {governor.action ?? "unknown"}
                        </Badge>
                        <Badge
                            variant="outline"
                            className="border-white/10 text-white/60"
                        >
                            source: {data.source}
                        </Badge>
                        <Badge
                            variant="outline"
                            className="border-white/10 text-white/60"
                        >
                            Hermes: {data.hermes?.tier ?? "—"}
                        </Badge>
                    </div>

                    <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                        <MetricTile
                            label="LiteLLM spend"
                            value={governor.global_spend ?? "n/a"}
                            sub={data.litellm_gateway_url}
                        />
                        <MetricTile
                            label="Gateway"
                            value={governor.gateway_ok ? "OK" : "FAIL"}
                            sub={governor.gateway}
                        />
                        <MetricTile
                            label="bd ready"
                            value={data.work_queue?.bd_ready_count ?? 0}
                            sub="issues desbloqueadas"
                        />
                        <MetricTile
                            label="Agent-OS abertas"
                            value={(
                                data.work_queue?.agent_os_specs ?? []
                            ).reduce((n, s) => n + (s.tasks_open ?? 0), 0)}
                            sub={`${(data.work_queue?.agent_os_specs ?? []).length} specs`}
                        />
                    </div>

                    <div className="grid gap-4 lg:grid-cols-3">
                        <Card className="bg-white/[0.02] border-white/5 lg:col-span-2">
                            <CardHeader>
                                <CardTitle className="text-white text-base flex items-center gap-2">
                                    <Gauge className="w-4 h-4 text-blue-400" />
                                    Tiers (governor)
                                </CardTitle>
                                <CardDescription>
                                    {governor.reason}
                                </CardDescription>
                            </CardHeader>
                            <CardContent className="space-y-3">
                                {["T3", "T4", "T5"].map((key) => (
                                    <div
                                        key={key}
                                        className="flex justify-between text-sm border-b border-white/5 pb-2"
                                    >
                                        <span className="text-white/70">
                                            {key}
                                        </span>
                                        <span className="text-white/50 font-mono text-xs">
                                            {formatTierSummary(tiers[key])}
                                        </span>
                                    </div>
                                ))}
                            </CardContent>
                        </Card>

                        <Card className="bg-white/[0.02] border-white/5">
                            <CardHeader>
                                <CardTitle className="text-white text-base flex items-center gap-2">
                                    <Wallet className="w-4 h-4 text-emerald-400" />
                                    Cursor
                                </CardTitle>
                            </CardHeader>
                            <CardContent>
                                <p className="text-sm text-white/50">
                                    {data.cursor?.note}
                                </p>
                                <div className="flex flex-wrap gap-1 mt-3">
                                    {(data.cursor?.auth_modes ?? []).map(
                                        (mode) => (
                                            <Badge
                                                key={mode}
                                                variant="secondary"
                                                className="text-[10px]"
                                            >
                                                {mode}
                                            </Badge>
                                        ),
                                    )}
                                </div>
                            </CardContent>
                        </Card>
                    </div>

                    <div className="grid gap-4 lg:grid-cols-2">
                        <Card className="bg-white/[0.02] border-white/5">
                            <CardHeader>
                                <CardTitle className="text-white text-base flex items-center gap-2">
                                    <Layers className="w-4 h-4 text-violet-400" />
                                    Virtual keys (teams)
                                </CardTitle>
                            </CardHeader>
                            <CardContent className="space-y-2">
                                {(data.teams ?? []).map((team) => (
                                    <div
                                        key={team.team_alias}
                                        className="flex justify-between text-sm py-1 border-b border-white/5"
                                    >
                                        <span className="text-white/80">
                                            {team.team_alias}
                                        </span>
                                        <span className="text-white/40">
                                            {team.harness} · $
                                            {team.max_budget_usd}
                                        </span>
                                    </div>
                                ))}
                            </CardContent>
                        </Card>

                        <Card className="bg-white/[0.02] border-white/5">
                            <CardHeader>
                                <CardTitle className="text-white text-base flex items-center gap-2">
                                    <Activity className="w-4 h-4 text-cyan-400" />
                                    Harness matrix
                                </CardTitle>
                            </CardHeader>
                            <CardContent className="space-y-2">
                                {(data.harnesses ?? []).map((h) => (
                                    <div
                                        key={h.id}
                                        className="text-sm py-1 border-b border-white/5"
                                    >
                                        <p className="text-white/80">{h.id}</p>
                                        <p className="text-[11px] text-white/40 font-mono">
                                            {(h.auth_modes ?? []).join(" · ")}
                                        </p>
                                    </div>
                                ))}
                            </CardContent>
                        </Card>
                    </div>

                    {(data.work_queue?.agent_os_specs ?? []).length > 0 && (
                        <Card className="bg-white/[0.02] border-white/5">
                            <CardHeader>
                                <CardTitle className="text-white text-base">
                                    Agent-OS — tarefas abertas
                                </CardTitle>
                            </CardHeader>
                            <CardContent className="space-y-2">
                                {data.work_queue.agent_os_specs
                                    .filter((s) => s.tasks_open > 0)
                                    .slice(0, 8)
                                    .map((spec) => (
                                        <div
                                            key={spec.path}
                                            className="flex justify-between text-sm"
                                        >
                                            <span className="text-white/70">
                                                {spec.slug}
                                            </span>
                                            <span className="text-white/40">
                                                {spec.tasks_open} open /{" "}
                                                {spec.tasks_done} done
                                            </span>
                                        </div>
                                    ))}
                            </CardContent>
                        </Card>
                    )}
                </>
            )}
        </div>
    );
}
