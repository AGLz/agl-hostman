import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useParams } from "react-router-dom";
import {
    AlertTriangle,
    Loader2,
    RefreshCw,
    Server,
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
    MISSION_CONTROL_POLL_MS,
    fetchHostSnapshot,
    healthBadgeClass,
    refreshHostSnapshot,
    semaphoreClass,
} from "@/lib/mission-control";

export default function HostMissionControl() {
    const { code = "aglsrv1" } = useParams();
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [error, setError] = useState(null);

    const load = useCallback(async () => {
        try {
            setError(null);
            const snapshot = await fetchHostSnapshot(code);
            setData(snapshot);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    }, [code]);

    const onRefresh = useCallback(async () => {
        setRefreshing(true);
        try {
            setError(null);
            const snapshot = await refreshHostSnapshot(code);
            setData(snapshot);
        } catch (err) {
            setError(err.message);
        } finally {
            setRefreshing(false);
        }
    }, [code]);

    useEffect(() => {
        load();
        const timer = setInterval(load, MISSION_CONTROL_POLL_MS);
        return () => clearInterval(timer);
    }, [load]);

    const summary = data?.summary ?? {};
    const guests = data?.guests ?? [];
    const services = data?.services ?? [];
    const alerts = data?.alerts ?? [];

    const categories = useMemo(() => {
        const map = new Map();
        for (const guest of guests) {
            const key = guest.category || "other";
            if (!map.has(key)) map.set(key, []);
            map.get(key).push(guest);
        }
        return [...map.entries()];
    }, [guests]);

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between gap-4 flex-wrap">
                <div>
                    <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Server className="w-6 h-6 text-sky-400" />
                        {data?.host?.name ?? code.toUpperCase()}
                        <span
                            className={`inline-block w-2.5 h-2.5 rounded-full ${semaphoreClass(summary.semaphore)}`}
                            title={`Semaphore: ${summary.semaphore ?? "gray"}`}
                        />
                    </h1>
                    <p className="text-sm text-white/40 mt-1">
                        Host Mission Control · registry + health HTTP · poll ~
                        {Math.round((data?.poll_interval_ms ?? MISSION_CONTROL_POLL_MS) / 1000)}s
                    </p>
                </div>
                <Button
                    variant="outline"
                    size="sm"
                    className="bg-white/5 border-white/10 text-white/70"
                    onClick={onRefresh}
                    disabled={loading || refreshing}
                >
                    <RefreshCw
                        className={`w-3.5 h-3.5 mr-1.5 ${refreshing ? "animate-spin" : ""}`}
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
                    <CardContent className="py-4 text-red-300 text-sm">
                        {error}
                    </CardContent>
                </Card>
            )}

            {data && (
                <>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                        <Stat label="Guests" value={summary.guests_total} />
                        <Stat label="Running" value={summary.guests_running} />
                        <Stat label="Services OK" value={summary.services_ok} />
                        <Stat label="Alertas" value={summary.alerts_total} />
                    </div>

                    {alerts.length > 0 && (
                        <Card className="bg-white/[0.02] border-white/5">
                            <CardHeader className="pb-2">
                                <CardTitle className="text-white text-base flex items-center gap-2">
                                    <AlertTriangle className="w-4 h-4 text-amber-400" />
                                    Runbooks activos
                                </CardTitle>
                                <CardDescription className="text-white/40">
                                    Regras do Service Registry
                                </CardDescription>
                            </CardHeader>
                            <CardContent className="space-y-2">
                                {alerts.map((alert) => (
                                    <div
                                        key={alert.id}
                                        className="flex items-start justify-between gap-3 text-sm border border-white/5 rounded-md px-3 py-2"
                                    >
                                        <div>
                                            <div className="text-white/90">
                                                {alert.title}
                                            </div>
                                            {alert.runbook && (
                                                <div className="text-white/35 text-xs mt-0.5">
                                                    {alert.runbook}
                                                </div>
                                            )}
                                        </div>
                                        <Badge
                                            variant="outline"
                                            className={
                                                alert.severity === "critical"
                                                    ? "border-red-500/40 text-red-300"
                                                    : "border-amber-500/40 text-amber-300"
                                            }
                                        >
                                            {alert.severity}
                                        </Badge>
                                    </div>
                                ))}
                            </CardContent>
                        </Card>
                    )}

                    <Card className="bg-white/[0.02] border-white/5">
                        <CardHeader className="pb-2">
                            <CardTitle className="text-white text-base">
                                Grid guests
                            </CardTitle>
                            <CardDescription className="text-white/40">
                                {guests.length} guests · fontes: registry
                                {data.sources?.proxmox ? " + Proxmox" : ""}
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-5">
                            {categories.map(([category, items]) => (
                                <div key={category}>
                                    <div className="text-xs uppercase tracking-wide text-white/35 mb-2">
                                        {category}
                                    </div>
                                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2">
                                        {items.map((guest) => (
                                            <div
                                                key={guest.vmid}
                                                className="rounded-md border border-white/5 bg-black/20 px-2.5 py-2"
                                            >
                                                <div className="flex items-center gap-2">
                                                    <span
                                                        className={`w-2 h-2 rounded-full shrink-0 ${semaphoreClass(guest.semaphore)}`}
                                                    />
                                                    <span className="text-white/90 text-sm truncate">
                                                        {guest.name}
                                                    </span>
                                                </div>
                                                <div className="text-[11px] text-white/35 mt-1 flex justify-between gap-2">
                                                    <span>
                                                        {guest.type} {guest.vmid}
                                                    </span>
                                                    <span>{guest.status}</span>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            ))}
                        </CardContent>
                    </Card>

                    <Card className="bg-white/[0.02] border-white/5">
                        <CardHeader className="pb-2">
                            <CardTitle className="text-white text-base">
                                Health services
                            </CardTitle>
                            <CardDescription className="text-white/40">
                                Probes HTTP do registry
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-1.5">
                            {services.map((svc) => (
                                <div
                                    key={svc.key}
                                    className="flex items-center justify-between gap-3 text-sm px-2 py-1.5 rounded border border-white/5"
                                >
                                    <div className="min-w-0">
                                        <div className="text-white/85 truncate">
                                            {svc.name}
                                            {svc.vmid ? (
                                                <span className="text-white/30 ml-2">
                                                    CT{svc.vmid}
                                                </span>
                                            ) : null}
                                        </div>
                                        <div className="text-[11px] text-white/30 truncate">
                                            {svc.health_url}
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2 shrink-0">
                                        {svc.latency_ms != null && (
                                            <span className="text-[11px] text-white/30">
                                                {svc.latency_ms}ms
                                            </span>
                                        )}
                                        <Badge
                                            variant="outline"
                                            className={healthBadgeClass(svc.health)}
                                        >
                                            {svc.health}
                                        </Badge>
                                    </div>
                                </div>
                            ))}
                        </CardContent>
                    </Card>

                    {data.checked_at && (
                        <p className="text-xs text-white/25">
                            Última leitura: {data.checked_at}
                        </p>
                    )}
                </>
            )}
        </div>
    );
}

function Stat({ label, value }) {
    return (
        <Card className="bg-white/[0.02] border-white/5">
            <CardContent className="py-3 px-4">
                <div className="text-[11px] uppercase tracking-wide text-white/35">
                    {label}
                </div>
                <div className="text-xl font-semibold text-white mt-0.5">
                    {value ?? "—"}
                </div>
            </CardContent>
        </Card>
    );
}
