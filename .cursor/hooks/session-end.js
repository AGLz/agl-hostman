#!/usr/bin/env node
const {
  readStdin,
  runExistingHook,
  transformToClaude,
  hookEnabled,
} = require("./adapter");
const { runExport } = require("./llm-wiki-export");
readStdin()
  .then((raw) => {
    const input = JSON.parse(raw || "{}");
    const claudeInput = transformToClaude(input);
    if (hookEnabled("session:end:marker", ["minimal", "standard", "strict"])) {
      runExistingHook("session-end-marker.js", claudeInput);
    }
    if (
      hookEnabled("session:end:wiki-export", ["minimal", "standard", "strict"])
    ) {
      runExport(claudeInput.transcript_path || "");
    }
    process.stdout.write(raw);
  })
  .catch(() => process.exit(0));
