import React, { useCallback, useEffect, useState } from "react";
import { Gauge, Loader2, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import LlmMonitorDashboard from "@/components/llm-monitor/LlmMonitorDashboard";
import {
    HARNESS_POLL_INTERVAL_MS,
    approveLlmProposal,
    fetchLlmMonitorStatus,
    rejectLlmProposal,
} from "@/lib/harness";

export default function MissionControlLlmMonitor() {
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [proposalActionId, setProposalActionId] = useState(null);
    const [actionError, setActionError] = useState(null);

    const load = useCallback(async () => {
        try {
            setError(null);
            const monitor = await fetchLlmMonitorStatus();
            setData(monitor);
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

    const handleApprove = useCallback(
        async (id) => {
            try {
                setActionError(null);
                setProposalActionId(id);
                await approveLlmProposal(id);
                await load();
            } catch (err) {
                setActionError(err.message);
            } finally {
                setProposalActionId(null);
            }
        },
        [load],
    );

    const handleReject = useCallback(
        async (id) => {
            try {
                setActionError(null);
                setProposalActionId(id);
                await rejectLlmProposal(id);
                await load();
            } catch (err) {
                setActionError(err.message);
            } finally {
                setProposalActionId(null);
            }
        },
        [load],
    );

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between gap-4 flex-wrap">
                <div>
                    <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Gauge className="w-6 h-6 text-amber-400" />
                        LLM Monitor
                    </h1>
                    <p className="text-white/50 text-sm mt-1">
                        Argus · quotas · probes · Tier B (Werner)
                    </p>
                </div>
                <Button
                    variant="outline"
                    size="sm"
                    className="border-white/10 text-white/70"
                    onClick={load}
                    disabled={loading}
                >
                    {loading ? (
                        <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                        <RefreshCw className="w-4 h-4" />
                    )}
                    <span className="ml-2">Actualizar</span>
                </Button>
            </div>

            {actionError && (
                <p className="text-sm text-red-300/80">{actionError}</p>
            )}

            <LlmMonitorDashboard
                data={data}
                error={error}
                compact={false}
                onApproveProposal={handleApprove}
                onRejectProposal={handleReject}
                proposalActionId={proposalActionId}
            />
        </div>
    );
}
