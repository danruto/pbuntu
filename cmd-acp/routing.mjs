// Model-id routing: which ids this host can actually run, and how to spell
// them.
//
// `cmd` resolves a model id by its leading path segment: a segment naming a
// provider in ~/.commandcode/providers.json routes to that provider, anything
// else routes to Command Code. The same model therefore appears twice in
// `cmd --list-models` — `exe-llm/deepseek/deepseek-v4-flash` and
// `deepseek/deepseek-v4-flash` — and only the prefixed spelling reaches the
// gateway this image configures.
//
// That matters because ~/.commandcode/config.json sets `localOnly: true`:
// under it, `cmd` refuses any call that would reach Command Code, and exits 1
// mid-turn. Advertising the unprefixed twin in the ACP catalog is offering a
// selection that cannot run, so the catalog is filtered to the runnable
// spelling and a selection of the other one is rewritten to it.

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// A model id is `<first-segment>/<rest>`; `first-segment` is a provider name
// when it is declared in providers.json. Ids are otherwise opaque — the
// gateway reuses upstream ids, so `deepseek/…` is a model family, not a
// provider, and an id may carry more than one slash.
const MODEL_ID = /^([^/]+)\/(.+)$/;

export function splitModelId(modelId) {
  const match = MODEL_ID.exec(modelId ?? "");
  return match ? { head: match[1], rest: match[2] } : null;
}

// Read ~/.commandcode/config.json. Returns {} when it is absent or
// unreadable — `cmd` treats a missing config as defaults, and so do we.
export function readCmdConfig(home = homedir()) {
  try {
    const parsed = JSON.parse(readFileSync(join(home, ".commandcode", "config.json"), "utf8"));
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

// Read the provider names declared in ~/.commandcode/providers.json.
export function readProviderNames(home = homedir()) {
  try {
    const parsed = JSON.parse(readFileSync(join(home, ".commandcode", "providers.json"), "utf8"));
    const providers = parsed?.provider ?? parsed?.providers;
    return providers && typeof providers === "object" ? Object.keys(providers) : [];
  } catch {
    return [];
  }
}

// Decide how this host routes model ids.
//
// `localOnly` (config file, --local-only, or CMD_LOCAL_ONLY) is the whole
// question: when it is on, an id that does not name a provider is refused, so
// only provider-prefixed ids are runnable. When it is off, both spellings
// reach a backend and nothing is filtered.
export function detectHost({ env = process.env, home = homedir() } = {}) {
  const config = readCmdConfig(home);
  const localOnly =
    env.CMD_LOCAL_ONLY === "1" || env.CMD_LOCAL_ONLY === "true" ? true : config.localOnly === true;
  return {
    localOnly,
    providerNames: readProviderNames(home),
  };
}

// True when `modelId` names one of `providerNames` in its leading segment.
function isProviderPrefixed(modelId, host) {
  const parts = splitModelId(modelId);
  return parts ? host.providerNames.includes(parts.head) : false;
}

// The provider-prefixed spelling of `modelId` within `models`, if one is
// listed. A prefixed id is the bare id with a provider segment prepended
// (`exe-llm/deepseek/deepseek-v4-flash` is `deepseek/deepseek-v4-flash` under
// `exe-llm`), so the twin is the entry whose remainder is this whole id —
// matching on tails would pair up unrelated models that share a suffix.
function findPrefixedTwin(modelId, host, models) {
  return (
    models.find((m) => {
      const other = splitModelId(m.modelId);
      return other && host.providerNames.includes(other.head) && other.rest === modelId;
    })?.modelId ?? null
  );
}

// Pick the spelling of `modelId` this host can run, or null if no spelling
// can. Under localOnly a bare id becomes its provider-prefixed twin when the
// catalog lists one, and is refused when it does not — offering it would hand
// paseo a selection that fails the turn. `models` is the catalog to search for
// a twin; without one, a bare id is refused outright.
export function resolveModelId(modelId, host, models = []) {
  if (!host.localOnly) return modelId;
  if (isProviderPrefixed(modelId, host)) return modelId;
  return findPrefixedTwin(modelId, host, models);
}

// Filter a `cmd --list-models` catalog down to what this host can run,
// collapsing the prefixed/unprefixed twins onto the runnable spelling.
//
// The surviving entry keeps the position of whichever spelling `cmd` listed
// first, so a host with providers still leads with `cmd`'s own ordering. Under
// localOnly an unprefixed id is replaced by its prefixed twin, and an
// unprefixed id with no twin is dropped rather than renamed.
export function filterCatalog(models, host) {
  const runnable = models.filter((m) => resolveModelId(m.modelId, host, models) !== null);
  if (!host.localOnly) return runnable;

  const seen = new Set();
  const out = [];
  for (const model of runnable) {
    const canonical = isProviderPrefixed(model.modelId, host)
      ? model
      : (runnable.find((m) => m.modelId === findPrefixedTwin(model.modelId, host, models)) ?? model);
    if (seen.has(canonical.modelId)) continue;
    seen.add(canonical.modelId);
    out.push(canonical);
  }
  return out;
}

// Choose the default model for a filtered catalog.
//
// `preferred` is the id `cmd` itself would run (from config.json, else
// --list-models' own "(default)" row). It is resolved the same way a
// session/set_model selection is, so a bare default becomes its prefixed twin
// instead of being discarded, and it falls back to the first runnable entry
// only when no spelling of it can run.
export function defaultModelId(models, host, preferred) {
  const resolved = preferred ? resolveModelId(preferred, host, models) : null;
  if (resolved && models.some((m) => m.modelId === resolved)) return resolved;
  return models.length ? models[0].modelId : null;
}
