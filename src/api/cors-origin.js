'use strict';

function parseCorsOrigin(value) {
  if (value === undefined || value === null) return undefined;
  if (value === true || value === false) return value;
  if (Array.isArray(value)) return value;
  if (typeof value !== 'string') return value;

  const trimmed = value.trim();
  if (!trimmed) return undefined;

  if (trimmed.startsWith('[')) {
    try {
      const parsed = JSON.parse(trimmed);
      if (Array.isArray(parsed)) {
        return parsed.map((v) => String(v).trim()).filter(Boolean);
      }
    } catch {
      // fallthrough
    }
  }

  const parts = trimmed
    .split(/[,\n]/g)
    .map((p) => p.trim())
    .filter(Boolean);

  if (parts.length <= 1) {
    return parts[0];
  }

  return parts;
}

module.exports = { parseCorsOrigin };

