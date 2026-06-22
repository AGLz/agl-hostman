import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(import.meta.dirname, "../..");

describe("harness mission control (Fase 5)", () => {
  it("regista rota React /mission-control/harness", () => {
    const app = readFileSync(join(ROOT, "src/resources/js/app.jsx"), "utf8");
    assert.match(app, /MissionControlHarness/);
    assert.match(app, /path="\/mission-control\/harness"/);
  });

  it("expõe API harness snapshot", () => {
    const api = readFileSync(join(ROOT, "src/routes/api/harness.php"), "utf8");
    assert.match(api, /HarnessController/);
    assert.match(api, /snapshot/);
  });

  it("export-harness-snapshot.sh existe e referencia storage Laravel", () => {
    const script = join(ROOT, "scripts/agl/export-harness-snapshot.sh");
    assert.ok(existsSync(script));
    const content = readFileSync(script, "utf8");
    assert.match(content, /storage\/app\/harness/);
  });
});
