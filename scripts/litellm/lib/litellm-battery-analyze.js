'use strict';

/**
 * Análise determinística de respostas LiteLLM/OpenAI-compat (testável sem rede).
 */

/**
 * @param {unknown} body - JSON já feito parse da /v1/chat/completions
 * @returns {{ ok: boolean, contentLength: number, usage: Record<string, number>|null, finishReason: string|null, errorMessage: string|null, hasChoices: boolean, hadReasoning: boolean }}
 */
function analyzeChatCompletion(body) {
  if (body === null || typeof body !== 'object') {
    return {
      ok: false,
      contentLength: 0,
      usage: null,
      finishReason: null,
      errorMessage: 'body inválido',
      hasChoices: false,
      hadReasoning: false,
    };
  }

  const err = body.error;
  if (err != null) {
    const msg =
      typeof err === 'string'
        ? err
        : typeof err.message === 'string'
          ? err.message
          : JSON.stringify(err);
    return {
      ok: false,
      contentLength: 0,
      usage: normalizeUsage(body.usage),
      finishReason: null,
      errorMessage: msg,
      hasChoices: Array.isArray(body.choices) && body.choices.length > 0,
      hadReasoning: false,
    };
  }

  const choices = body.choices;
  const hasChoices = Array.isArray(choices) && choices.length > 0;
  const msg0 = hasChoices && choices[0].message ? choices[0].message : {};
  const content = typeof msg0.content === 'string' ? msg0.content : '';
  const reasoning =
    typeof msg0.reasoning_content === 'string' ? msg0.reasoning_content : '';
  const hadReasoning = reasoning.length > 2;
  const contentLength = content.length + reasoning.length;
  const finishReason =
    hasChoices && typeof choices[0].finish_reason === 'string'
      ? choices[0].finish_reason
      : null;

  const ok =
    hasChoices && (content.trim().length > 0 || hadReasoning);

  return {
    ok,
    contentLength,
    usage: normalizeUsage(body.usage),
    finishReason,
    errorMessage: ok ? null : 'sem content/reasoning útil',
    hasChoices,
    hadReasoning,
  };
}

/**
 * @param {unknown} u
 * @returns {Record<string, number>|null}
 */
function normalizeUsage(u) {
  if (u === null || typeof u !== 'object') return null;
  /** @type {Record<string, number>} */
  const out = {};
  for (const k of ['prompt_tokens', 'completion_tokens', 'total_tokens']) {
    if (typeof u[k] === 'number' && Number.isFinite(u[k])) out[k] = u[k];
  }
  return Object.keys(out).length ? out : null;
}

/**
 * @param {string} message
 * @param {string} rawBody
 * @returns {boolean}
 */
function looksLikeRateLimit(message, rawBody) {
  const blob = `${message || ''} ${rawBody || ''}`.toLowerCase();
  return (
    /429\b/.test(blob) ||
    /rate[\s_-]?limit/.test(blob) ||
    /too many requests/.test(blob)
  );
}

/**
 * Extrai campos úteis de um item de /v1/models (OpenAI-compat + extensões).
 * @param {unknown} item
 * @returns {{ id: string, contextLength: number|null, root: string|null }}
 */
function summarizeModelListItem(item) {
  if (item === null || typeof item !== 'object') {
    return { id: '', contextLength: null, root: null };
  }
  const id = typeof item.id === 'string' ? item.id : '';
  let contextLength = null;
  if (typeof item.context_length === 'number') contextLength = item.context_length;
  else if (typeof item.max_model_len === 'number') contextLength = item.max_model_len;
  const root = typeof item.root === 'string' ? item.root : null;
  return { id, contextLength, root };
}

module.exports = {
  analyzeChatCompletion,
  normalizeUsage,
  looksLikeRateLimit,
  summarizeModelListItem,
};
