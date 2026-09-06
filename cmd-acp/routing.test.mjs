import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  defaultModelId,
  detectHost,
  filterCatalog,
  readProviderNames,
  resolveModelId,
  splitModelId,
} from "./routing.mjs";

// A host laid out like the dev image: one BYOK provider, localOnly on. The
// catalog deliberately mixes the two spellings of the same model plus a bare id
// the provider does not carry, which is the case that must be dropped rather
// than renamed.
function localOnlyHost() {
  const home = mkdtempSync(join(tmpdir(), "cmd-acp-home-"));
  mkdirSync(join(home, ".commandcode"));
  writeFileSync(
    join(home, ".commandcode", "config.json"),
    JSON.stringify({ localOnly: true, model: "exe-llm/deepseek/deepseek-v4-flash" }),
  );
  writeFileSync(
    join(home, ".commandcode", "providers.json"),
    JSON.stringify({
      provider: {
        "exe-llm": { api: "openai-completions", models: { "deepseek/deepseek-v4-flash": {} } },
      },
    }),
  );
  return { home, host: detectHost({ env: {}, home }) };
}

function catalog() {
  return [
    { modelId: "deepseek/deepseek-v4-flash", name: "deepseek/deepseek-v4-flash" },
    { modelId: "deepseek/deepseek-v4-pro", name: "deepseek/deepseek-v4-pro" },
    { modelId: "exe-llm/deepseek/deepseek-v4-flash", name: "exe-llm/deepseek/deepseek-v4-flash" },
    { modelId: "exe-llm/zai-org/glm-5.2", name: "exe-llm/zai-org/glm-5.2" },
  ];
}

test("splitModelId separates a leading segment from the rest", () => {
  assert.deepEqual(splitModelId("exe-llm/deepseek/deepseek-v4-flash"), {
    head: "exe-llm",
    rest: "deepseek/deepseek-v4-flash",
  });
  assert.deepEqual(splitModelId("deepseek/deepseek-v4-pro"), {
    head: "deepseek",
    rest: "deepseek-v4-pro",
  });
  assert.equal(splitModelId("nonsense"), null);
});

test("detectHost reads localOnly from the config, and lets the env force it", () => {
  const { home, host } = localOnlyHost();
  assert.equal(host.localOnly, true);
  assert.deepEqual(host.providerNames, ["exe-llm"]);

  // CMD_LOCAL_ONLY wins even when the config says otherwise — `cmd` honours the
  // variable, so a host with no config file is still detected correctly.
  const off = mkdtempSync(join(tmpdir(), "cmd-acp-home-"));
  mkdirSync(join(off, ".commandcode"));
  writeFileSync(join(off, ".commandcode", "config.json"), JSON.stringify({}));
  assert.equal(detectHost({ env: {}, home: off }).localOnly, false);
  assert.equal(detectHost({ env: { CMD_LOCAL_ONLY: "1" }, home: off }).localOnly, true);
});

test("detectHost tolerates a host with no .commandcode at all", () => {
  const home = mkdtempSync(join(tmpdir(), "cmd-acp-empty-"));
  const host = detectHost({ env: {}, home });
  assert.equal(host.localOnly, false);
  assert.deepEqual(host.providerNames, []);
});

test("readProviderNames returns [] when providers.json is absent", () => {
  const home = mkdtempSync(join(tmpdir(), "cmd-acp-noprov-"));
  assert.deepEqual(readProviderNames(home), []);
});

test("localOnly host: bare ids resolve to their provider twin, others are refused", () => {
  const { host } = localOnlyHost();
  assert.equal(
    resolveModelId("deepseek/deepseek-v4-flash", host, catalog()),
    "exe-llm/deepseek/deepseek-v4-flash",
  );
  // Already prefixed: passes through untouched.
  assert.equal(
    resolveModelId("exe-llm/deepseek/deepseek-v4-flash", host),
    "exe-llm/deepseek/deepseek-v4-flash",
  );
  // No prefixed twin: refused, because routing it would reach Command Code.
  assert.equal(resolveModelId("deepseek/deepseek-v4-pro", host, catalog()), null);
  // Same question with no catalog to search: still refused.
  assert.equal(resolveModelId("deepseek/deepseek-v4-flash", host), null);
});

test("non-localOnly host: every id is runnable and left alone", () => {
  const host = { localOnly: false, providerNames: ["exe-llm"] };
  assert.equal(resolveModelId("deepseek/deepseek-v4-flash", host), "deepseek/deepseek-v4-flash");
  assert.equal(resolveModelId("anything/at/all", host), "anything/at/all");
});

test("localOnly host: catalog collapses twins and drops unroutable ids", () => {
  const { host } = localOnlyHost();
  const ids = filterCatalog(catalog(), host).map((m) => m.modelId);
  assert.deepEqual(ids, ["exe-llm/deepseek/deepseek-v4-flash", "exe-llm/zai-org/glm-5.2"]);
});

test("localOnly host: a bare id with no twin is dropped, not renamed", () => {
  const { host } = localOnlyHost();
  const ids = filterCatalog([{ modelId: "openai/gpt-5" }], host).map((m) => m.modelId);
  assert.deepEqual(ids, []);
});

test("non-localOnly host: catalog is unchanged", () => {
  const host = { localOnly: false, providerNames: ["exe-llm"] };
  const ids = filterCatalog(catalog(), host).map((m) => m.modelId);
  assert.deepEqual(ids, catalog().map((m) => m.modelId));
});

test("default: a bare configured default is rewritten to its twin", () => {
  const { host } = localOnlyHost();
  const models = filterCatalog(catalog(), host);
  assert.equal(
    defaultModelId(models, host, "deepseek/deepseek-v4-flash"),
    "exe-llm/deepseek/deepseek-v4-flash",
  );
});

test("default: falls back to the first runnable model when the preferred one cannot run", () => {
  const { host } = localOnlyHost();
  const models = filterCatalog(catalog(), host);
  assert.equal(defaultModelId(models, host, "deepseek/deepseek-v4-pro"), models[0].modelId);
});

test("default: null when there is nothing runnable", () => {
  const { host } = localOnlyHost();
  assert.equal(defaultModelId([], host, "deepseek/deepseek-v4-flash"), null);
});
