"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const CONFIG = path.join(__dirname, "../../config/litellm/config.yaml");
const CONFIG_REMOTE = path.join(
  __dirname,
  "../../config/litellm/config-remote.yaml",
);

function assertGeminiDirectAndOpenRouter(yaml, label) {
  assert.match(
    yaml,
    /model_name:\s*"?gemini-lite"?/,
    `${label}: gemini-lite directo`,
  );
  assert.match(
    yaml,
    /model:\s*gemini\/gemini-2\.5-flash-lite/,
    `${label}: gemini/gemini-2.5-flash-lite`,
  );
  assert.match(
    yaml,
    /api_base:\s*https:\/\/aiplatform\.googleapis\.com\/v1\/publishers\/google/,
    `${label}: api_base Vertex Express publishers/google`,
  );
  assert.doesNotMatch(
    yaml,
    /vertex_ai\/gemini-/,
    `${label}: sem vertex_ai/ (exige ADC)`,
  );
  assert.match(
    yaml,
    /model_name:\s*"?openrouter\/google\/gemini-2\.5-flash-lite:free"?/,
    `${label}: openrouter gemini free mantido`,
  );
  assert.match(yaml, /GEMINI_API_KEY/, `${label}: GEMINI_API_KEY referenciada`);
}

function assertGeminiOpenRouterOnly(yaml, label) {
  assert.doesNotMatch(
    yaml,
    /model_name:\s*"?gemini-lite"?/,
    `${label}: gemini-lite removido`,
  );
  assert.match(
    yaml,
    /model_name:\s*"?openrouter\/google\/gemini-2\.5-flash-lite:free"?/,
    `${label}: openrouter gemini free mantido`,
  );
}

test("LiteLLM: Gemini directo + OpenRouter :free em config.yaml", () => {
  assertGeminiDirectAndOpenRouter(
    fs.readFileSync(CONFIG, "utf8"),
    "config.yaml",
  );
});

test("LiteLLM: config-remote.yaml (aliases OR gemini)", () => {
  assertGeminiOpenRouterOnly(
    fs.readFileSync(CONFIG_REMOTE, "utf8"),
    "config-remote.yaml",
  );
});
