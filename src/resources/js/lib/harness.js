export const HARNESS_POLL_INTERVAL_MS = 15000;

async function fetchJson(url) {
    const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
        throw new Error(
            data.error || data.message || `HTTP ${response.status}`,
        );
    }
    return data;
}

export async function fetchHarnessSnapshot() {
    return fetchJson("/api/harness/snapshot");
}

export async function fetchLlmMonitorStatus() {
    return fetchJson("/api/llm-monitor/status");
}

function csrfToken() {
    return (
        document
            .querySelector('meta[name="csrf-token"]')
            ?.getAttribute("content") ?? ""
    );
}

async function postJson(url, body = {}) {
    const response = await fetch(url, {
        method: "POST",
        headers: {
            Accept: "application/json",
            "Content-Type": "application/json",
            "X-CSRF-TOKEN": csrfToken(),
            "X-Requested-With": "XMLHttpRequest",
        },
        credentials: "same-origin",
        body: JSON.stringify(body),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
        throw new Error(
            data.message || data.error || `HTTP ${response.status}`,
        );
    }
    return data;
}

export async function approveLlmProposal(proposalId) {
    return postJson(`/api/llm-monitor/proposals/${proposalId}/approve`);
}

export async function rejectLlmProposal(proposalId) {
    return postJson(`/api/llm-monitor/proposals/${proposalId}/reject`);
}

export function overallBadgeClass(overall) {
    switch (overall) {
        case "ok":
            return "bg-green-500/10 text-green-400 border-green-500/20";
        case "warn":
            return "bg-yellow-500/10 text-yellow-300 border-yellow-500/20";
        case "degraded":
            return "bg-orange-500/10 text-orange-300 border-orange-500/20";
        case "blocked":
            return "bg-red-500/10 text-red-300 border-red-500/20";
        default:
            return "bg-white/5 text-white/60 border-white/10";
    }
}

export function actionBadgeClass(action) {
    switch (action) {
        case "ok":
        case "skipped":
            return "bg-green-500/10 text-green-400 border-green-500/20";
        case "warn-spend":
        case "free-tier":
            return "bg-yellow-500/10 text-yellow-300 border-yellow-500/20";
        case "degraded":
            return "bg-orange-500/10 text-orange-300 border-orange-500/20";
        case "critical":
        case "unknown":
            return "bg-red-500/10 text-red-300 border-red-500/20";
        default:
            return "bg-white/5 text-white/60 border-white/10";
    }
}

export function formatTierSummary(tier) {
    if (!tier) return "—";
    return `${tier.ok ?? 0} ok · ${tier.quota ?? 0} quota · ${tier.fail ?? 0} fail`;
}
