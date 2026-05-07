export const POLL_INTERVAL_MS = 5000;

async function fetchJson(url, options = {}) {
    const response = await fetch(url, {
        headers: {
            Accept: 'application/json',
            ...(options.headers || {}),
        },
        ...options,
    });

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
        throw new Error(data.error || data.message || `HTTP ${response.status}`);
    }

    return data;
}

export async function fetchOpenClawStatus() {
    return fetchJson('/api/openclaw/status');
}

export async function fetchOpenClawAgents() {
    const data = await fetchJson('/api/openclaw/agents');
    return data.agents || [];
}

export async function fetchMissionControlSnapshot() {
    const [agents, tasks, openclaw] = await Promise.all([
        fetchJson('/api/agents'),
        fetchJson('/api/tasks/summary'),
        fetchOpenClawStatus(),
    ]);

    return { agents, tasks, openclaw };
}

export async function chatWithOpenClawAgent(agentId, message, history = []) {
    return fetchJson(`/api/openclaw/agents/${encodeURIComponent(agentId)}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message, history }),
    });
}

export function formatCheckedAt(value) {
    if (!value) return 'never';
    const date = value instanceof Date ? value : new Date(value);

    if (Number.isNaN(date.getTime())) return String(value);

    return date.toLocaleTimeString();
}

export function formatAgentLastActive(value) {
    if (!value) return 'never';
    if (['live', 'unreachable', 'no sessions', 'unknown'].includes(value)) return value;

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);

    const diffSeconds = Math.max(0, Math.round((Date.now() - date.getTime()) / 1000));
    if (diffSeconds < 60) return `${diffSeconds}s ago`;
    if (diffSeconds < 3600) return `${Math.round(diffSeconds / 60)}m ago`;
    if (diffSeconds < 86400) return `${Math.round(diffSeconds / 3600)}h ago`;

    return date.toLocaleString();
}
