export const MISSION_CONTROL_POLL_MS = 45000;

async function fetchJson(url, options = {}) {
    const response = await fetch(url, {
        headers: { Accept: "application/json", ...(options.headers || {}) },
        credentials: "same-origin",
        ...options,
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
        throw new Error(
            data.error || data.message || `HTTP ${response.status}`,
        );
    }
    return data;
}

function csrfToken() {
    return (
        document
            .querySelector('meta[name="csrf-token"]')
            ?.getAttribute("content") ?? ""
    );
}

export async function fetchHostSnapshot(code) {
    return fetchJson(`/api/mission-control/hosts/${code}/snapshot`);
}

export async function refreshHostSnapshot(code) {
    return fetchJson(`/api/mission-control/hosts/${code}/refresh`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "X-CSRF-TOKEN": csrfToken(),
            "X-Requested-With": "XMLHttpRequest",
        },
        body: "{}",
    });
}

export function semaphoreClass(semaphore) {
    switch (semaphore) {
        case "green":
            return "bg-emerald-500";
        case "yellow":
            return "bg-amber-400";
        case "red":
            return "bg-red-500";
        default:
            return "bg-white/30";
    }
}

export function healthBadgeClass(health) {
    switch (health) {
        case "ok":
            return "bg-emerald-500/15 text-emerald-300 border-emerald-500/30";
        case "down":
            return "bg-red-500/15 text-red-300 border-red-500/30";
        default:
            return "bg-white/5 text-white/50 border-white/10";
    }
}
