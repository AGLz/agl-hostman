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
    return new Date(value).toLocaleTimeString();
}
