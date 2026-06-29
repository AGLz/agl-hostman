import React from "react";
import { Link } from "react-router-dom";
import { Gauge, ExternalLink } from "lucide-react";
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
    actionBadgeClass,
    formatTierSummary,
    overallBadgeClass,
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

function TierRow({ tier, data }) {
    if (!data) return null;
    return (
        <div className="flex justify-between text-sm border-b border-white/5 py-2">
            <span className="text-white/70 font-mono">{tier}</span>
            <span className="text-white/40">{formatTierSummary(data)}</span>
        </div>
    );
}

/**
 * Painel LLM Monitor — compact (Harness) ou full (página dedicada).
 */
export default function LlmMonitorDashboard({
    data,
    error,
    compact = false,
    onApproveProposal,
    onRejectProposal,
    proposalActionId = null,
}) {
    const governor = data?.governor ?? {};
    const tiers = governor.tiers ?? {};

    return (
        <Card className="bg-white/[0.02] border-white/5">
            <CardHeader>
                <div className="flex items-start justify-between gap-3 flex-wrap">
                    <div>
                        <CardTitle className="text-white text-base flex items-center gap-2">
                            <Gauge className="w-4 h-4 text-amber-400" />
                            LLM Monitor (Argus / DB)
                        </CardTitle>
                        <CardDescription>
                            CT134 · ingest governor · probes Horizon · LiteLLM
                            CT186
                        </CardDescription>
                    </div>
                    {compact && (
                        <Button
                            variant="outline"
                            size="sm"
                            className="border-white/10 text-white/70"
                            asChild
                        >
                            <Link to="/mission-control/llm-monitor">
                                Ver completo
                                <ExternalLink className="w-3 h-3 ml-1" />
                            </Link>
                        </Button>
                    )}
                </div>
            </CardHeader>
            <CardContent className="space-y-4">
                {error && <p className="text-sm text-red-300/80">{error}</p>}
                {!data && !error && (
                    <p className="text-sm text-white/40">A carregar…</p>
                )}
                {data && (
                    <>
                        <div className="flex flex-wrap gap-2">
                            <Badge className={overallBadgeClass(data.overall)}>
                                overall: {data.overall}
                            </Badge>
                            <Badge
                                className={actionBadgeClass(
                                    governor.action ?? "unknown",
                                )}
                            >
                                governor: {governor.action ?? "unknown"}
                            </Badge>
                            <Badge
                                variant="outline"
                                className="border-white/10 text-white/60"
                            >
                                gateway: {data.gateway?.ok ? "OK" : "FAIL"}
                            </Badge>
                            <Badge
                                variant="outline"
                                className="border-white/10 text-white/60"
                            >
                                spend: $
                                {data.gateway?.global_spend_usd ?? "n/a"}
                            </Badge>
                        </div>

                        {governor.reason && (
                            <p className="text-xs text-white/50">
                                {governor.reason}
                            </p>
                        )}

                        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
                            <MetricTile
                                label="Snapshots"
                                value={(data.providers ?? []).length}
                                sub={`${(data.limit_events_open ?? []).length} eventos abertos`}
                            />
                            <MetricTile
                                label="Probes recentes"
                                value={(data.recent_probes ?? []).length}
                                sub={`${(data.pending_proposals ?? []).length} propostas Tier B`}
                            />
                            <MetricTile
                                label="Spend warn"
                                value={`$${data.gateway?.spend_warn_usd ?? "—"}`}
                                sub={data.checked_at ?? ""}
                            />
                            <MetricTile
                                label="Gateway"
                                value={data.gateway?.ok ? "healthy" : "down"}
                                sub={data.gateway?.url ?? ""}
                            />
                        </div>

                        {!compact && Object.keys(tiers).length > 0 && (
                            <div className="rounded-lg border border-white/5 p-3">
                                <p className="text-xs text-white/40 mb-2">
                                    Tiers (governor)
                                </p>
                                {["T3", "T4", "T5"].map((t) => (
                                    <TierRow key={t} tier={t} data={tiers[t]} />
                                ))}
                            </div>
                        )}

                        {(data.providers ?? []).length > 0 && (
                            <div>
                                <p className="text-xs text-white/40 mb-2">
                                    Providers (último snapshot)
                                </p>
                                <div
                                    className={`space-y-1 overflow-y-auto ${compact ? "max-h-40" : "max-h-64"}`}
                                >
                                    {data.providers
                                        .slice(0, compact ? 12 : 50)
                                        .map((p) => (
                                            <div
                                                key={`${p.provider}-${p.model_alias}`}
                                                className="flex justify-between text-xs border-b border-white/5 py-1"
                                            >
                                                <span className="text-white/70">
                                                    {p.model_alias}
                                                </span>
                                                <span className="text-white/40 font-mono">
                                                    {p.tier} · {p.status}
                                                </span>
                                            </div>
                                        ))}
                                </div>
                            </div>
                        )}

                        {!compact &&
                            (data.limit_events_open ?? []).length > 0 && (
                                <div>
                                    <p className="text-xs text-white/40 mb-2">
                                        Eventos de limite (abertos)
                                    </p>
                                    <div className="space-y-2 max-h-48 overflow-y-auto">
                                        {(data.limit_events_open ?? []).map(
                                            (e) => (
                                                <div
                                                    key={e.id}
                                                    className="text-xs rounded border border-red-500/10 bg-red-500/5 p-2"
                                                >
                                                    <span className="text-red-300/90 font-mono">
                                                        {e.severity}
                                                    </span>
                                                    <span className="text-white/50">
                                                        {" "}
                                                        · {e.provider} ·{" "}
                                                        {e.window}
                                                    </span>
                                                    <p className="text-white/60 mt-1">
                                                        {e.message}
                                                    </p>
                                                </div>
                                            ),
                                        )}
                                    </div>
                                </div>
                            )}

                        {!compact &&
                            (data.pending_proposals ?? []).length > 0 && (
                                <div>
                                    <p className="text-xs text-white/40 mb-2">
                                        Propostas Tier B (pendentes)
                                    </p>
                                    <div className="space-y-2">
                                        {(data.pending_proposals ?? []).map(
                                            (p) => (
                                                <div
                                                    key={p.id}
                                                    className="text-xs rounded border border-amber-500/10 bg-amber-500/5 p-2 space-y-2"
                                                >
                                                    <div>
                                                        <span className="text-amber-300/90">
                                                            {p.tier}
                                                        </span>
                                                        <span className="text-white/50">
                                                            {" "}
                                                            · {p.status}
                                                        </span>
                                                        <p className="text-white/60 mt-1">
                                                            {p.reason}
                                                        </p>
                                                    </div>
                                                    {!compact &&
                                                        onApproveProposal &&
                                                        onRejectProposal && (
                                                            <div className="flex gap-2">
                                                                <Button
                                                                    size="sm"
                                                                    variant="outline"
                                                                    className="h-7 text-xs border-green-500/30 text-green-300"
                                                                    disabled={
                                                                        proposalActionId ===
                                                                        p.id
                                                                    }
                                                                    onClick={() =>
                                                                        onApproveProposal(
                                                                            p.id,
                                                                        )
                                                                    }
                                                                >
                                                                    Aprovar
                                                                </Button>
                                                                <Button
                                                                    size="sm"
                                                                    variant="outline"
                                                                    className="h-7 text-xs border-red-500/30 text-red-300"
                                                                    disabled={
                                                                        proposalActionId ===
                                                                        p.id
                                                                    }
                                                                    onClick={() =>
                                                                        onRejectProposal(
                                                                            p.id,
                                                                        )
                                                                    }
                                                                >
                                                                    Rejeitar
                                                                </Button>
                                                            </div>
                                                        )}
                                                </div>
                                            ),
                                        )}
                                    </div>
                                </div>
                            )}

                        {!compact && (data.recent_probes ?? []).length > 0 && (
                            <div>
                                <p className="text-xs text-white/40 mb-2">
                                    Probes recentes
                                </p>
                                <div className="overflow-x-auto">
                                    <table className="w-full text-xs">
                                        <thead>
                                            <tr className="text-white/40 text-left">
                                                <th className="py-1 pr-2">
                                                    modelo
                                                </th>
                                                <th className="py-1 pr-2">
                                                    tipo
                                                </th>
                                                <th className="py-1 pr-2">
                                                    resultado
                                                </th>
                                                <th className="py-1">ms</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {(data.recent_probes ?? []).map(
                                                (r) => (
                                                    <tr
                                                        key={r.id}
                                                        className="border-t border-white/5 text-white/70"
                                                    >
                                                        <td className="py-1 pr-2 font-mono">
                                                            {r.model}
                                                        </td>
                                                        <td className="py-1 pr-2">
                                                            {r.probe_type}
                                                        </td>
                                                        <td className="py-1 pr-2">
                                                            {r.result}
                                                        </td>
                                                        <td className="py-1">
                                                            {r.latency_ms ??
                                                                "—"}
                                                        </td>
                                                    </tr>
                                                ),
                                            )}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        )}
                    </>
                )}
            </CardContent>
        </Card>
    );
}
