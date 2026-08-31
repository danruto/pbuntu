#!/usr/bin/env node
// probe-gateway-limits — measure the real context and output ceilings for the
// exe.dev llm gateway providers that ship no `limits`, and emit the
// PROBED_LIMITS table for pi-extension/integration_catalog.ts.
//
//   scripts/probe-gateway-limits.mjs [ssh-host] [--save probe.tsv] [--raw probe.tsv]
//
// https://llm.int.exe.xyz is only reachable from inside an exe.dev VM, so the
// requests run there over ssh. Each probe asks for an absurd max_tokens: a
// provider that enforces a ceiling names it in the 400, which bills no tokens.
// Re-run this after exe.dev adds models rather than hand-editing the table.
//
// A reported ceiling is then asked for directly, because a provider can name a
// bound it does not honour: poolside answers an absurd request with "less than
// or equal to 262144" and then rejects 251454 as over its real cap of 32768.
// Only a ceiling that survives being requested reaches the table.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

const args = process.argv.slice(2);
const flag = (name) => {
	const i = args.indexOf(name);
	return i === -1 ? undefined : args[i + 1];
};
const rawFile = flag("--raw");
const saveFile = flag("--save");
const host =
	args.find((a) => !a.startsWith("--") && a !== rawFile && a !== saveFile) ??
	"pb-base.exe.xyz";

const ABSURD_MAX_TOKENS = 9999999;
// What integration_catalog.ts falls back to when nothing describes a window.
// An output cap has to fit inside the window the model is actually given, not
// the one we wish we knew.
const DEFAULT_CONTEXT_WINDOW = 128000;
// A provider that keeps naming a lower ceiling every time is walking us down to
// its real one; four asks is far more than any of them have needed.
const MAX_CONFIRM_ROUNDS = 4;
const ROUND_SEPARATOR = "\n=== round ===\n";

// Ceilings that no probe can reach and exe.dev publishes for no provider. Each
// entry is keyed by base model and must cite the evidence it rests on. Delete
// one the moment a probe or a published limit can answer instead.
const MANUAL_MAX_TOKENS = new Map([
	// exe.dev ships no max_output_tokens for grok-4.6 on any route, and the one
	// working route cannot be probed: commandai neither rejects an oversized
	// max_tokens nor clamps one, and asked for 8000 it returned exactly 8000
	// visible tokens. 30000 is what exe.dev publishes for grok-4.5 on the same
	// provider and the same 500000 window, so grok-4.6 cannot refuse it. It is a
	// floor that beats the 4096 default, not a measured ceiling.
	["grok-4.6", 30000],
]);

// Every distinct phrasing the upstreams behind commandai and opencode-go use to
// report an output ceiling. A phrasing missing from this list makes its models
// land in the unresolved footer, which is the signal to add it.
const MAX_OUTPUT_PATTERNS = [
	/must be between 0 and (\d+)/,
	/valid range of max_tokens is \[1, ?(\d+)\]/,
	/Range of max_tokens should be \[1, ?(\d+)\]/,
	/does not support max tokens > (\d+)/,
	/Input should be less than or equal to (\d+)/,
	/is not less or equal to (\d+)/,
	/supports at most (\d+) completion tokens/,
	/限制数值范围\[1, ?(\d+)\]/,
];
const CONTEXT_PATTERN = /maximum context length is (\d+) tokens/;

function ssh(script) {
	return execFileSync("ssh", ["-o", "BatchMode=yes", host, "bash -s"], {
		input: script,
		encoding: "utf8",
		maxBuffer: 64 * 1024 * 1024,
	});
}

function fetchCatalog() {
	return JSON.parse(
		ssh("curl -sS --max-time 60 https://llm.int.exe.xyz/models.json"),
	);
}

// The protocols pi speaks. A model advertising none of them never becomes a
// route, so probing it would only waste requests.
const USABLE_APIS = new Set([
	"openai_responses",
	"anthropic_messages",
	"openai_chat",
]);

// Any usable model exe.dev leaves a hole in. Whole providers are usually
// missing (commandai and opencode-go carry no limits at all), but a normalized
// provider can still have a gap: xai declares max_output_tokens for grok-4.5
// and nothing for grok-4.6, which drops it to the 4096 default like the rest.
function needsLimits(model) {
	if (!(model.apis ?? []).some((api) => USABLE_APIS.has(api))) return false;
	return !model.limits?.max_output_tokens || !model.limits?.context_window;
}

// `asks` is [modelID, maxTokens] pairs. The reply is one TSV line per ask, with
// the asked-for value kept so a later parse knows what the answer was about.
function probeAt(asks) {
	const lines = asks.map(([id, maxTokens]) => `${id} ${maxTokens}`).join("\n");
	return ssh(`
set -u
probe() {
  set -- $1
  id=$1; want=$2
  b=$(curl -sS --max-time 90 -X POST https://llm.int.exe.xyz/v1/chat/completions \
    -H 'content-type: application/json' \
    -d "$(jq -nc --arg m "$id" --argjson t "$want" '{model:$m,max_tokens:$t,messages:[{role:"user",content:"hi"}]}')" 2>&1)
  printf '%s\\t%s\\t%s\\n' "$id" "$want" "$(printf '%s' "$b" | tr '\\n' ' ')"
}
export -f probe
cat <<'ASKS' | xargs -P 8 -I{} bash -c 'probe "$@"' _ {}
${lines}
ASKS
`);
}

function parseRound(raw) {
	const results = new Map();
	for (const line of raw.split("\n")) {
		const parts = line.split("\t");
		if (parts.length < 3) continue;
		const [id, asked, body] = [parts[0], Number(parts[1]), parts.slice(2).join("\t")];
		let ceiling;
		for (const pattern of MAX_OUTPUT_PATTERNS) {
			const hit = body.match(pattern);
			if (hit) {
				ceiling = Number(hit[1]);
				break;
			}
		}
		const ctxHit = body.match(CONTEXT_PATTERN);
		results.set(id, {
			asked,
			ceiling,
			contextWindow: ctxHit ? Number(ctxHit[1]) : undefined,
			// An accepted request means the provider is willing to serve what we
			// asked for, which is the only proof a ceiling is real.
			accepted: body.includes('"choices"'),
		});
	}
	return results;
}

// Walk each model down to a ceiling it will actually accept. Round 0 asks for an
// absurd value; every later round asks for whatever the last 400 named.
function probeRounds(models, transcript) {
	const state = new Map();
	let pending = new Map(models.map((m) => [m.id, ABSURD_MAX_TOKENS]));
	let text = "";
	for (let round = 0; round < MAX_CONFIRM_ROUNDS && pending.size > 0; round++) {
		const raw = transcript
			? transcript[round] ?? ""
			: probeAt([...pending]);
		text += (text ? ROUND_SEPARATOR : "") + raw;
		const parsed = parseRound(raw);
		const next = new Map();
		for (const [id, asked] of pending) {
			const hit = parsed.get(id);
			const prev = state.get(id) ?? {};
			const merged = {
				contextWindow: hit?.contextWindow ?? prev.contextWindow,
				accepted: hit?.accepted ?? prev.accepted,
				maxTokens: prev.maxTokens,
			};
			if (hit?.ceiling !== undefined && hit.ceiling < asked) {
				// A lower bound than we asked for: believe it only once it holds.
				merged.maxTokens = hit.ceiling;
				next.set(id, hit.ceiling);
			} else if (round === 0) {
				// No ceiling named for an absurd ask, so there is nothing to confirm.
				merged.maxTokens = undefined;
			} else if (!hit?.accepted) {
				// The named ceiling was refused, or the provider never answered.
				// Asserting it would break a model that works fine on the default.
				merged.maxTokens = undefined;
			}
			state.set(id, merged);
		}
		pending = next;
	}
	// Anything still walking downward never settled; do not assert a value.
	for (const id of pending.keys()) {
		const prev = state.get(id);
		if (prev) state.set(id, { ...prev, maxTokens: undefined });
	}
	return { state, text };
}

// Collapse a provider's model id to the underlying model so the same model
// served by several providers can be matched. Vendor prefixes, billing
// variants, fireworks' `5p3` spelling, and dated snapshots are all noise here.
function baseModel(nativeID) {
	return nativeID
		.toLowerCase()
		.replace(/^accounts\/fireworks\/models\//, "")
		.replace(/^[^/]+\//, "")
		.replace(/-(free|paid)$/, "")
		.replace(/-\d{6,8}$/, "")
		.replace(/-\d{4}$/, "")
		.replace(/(\d)p(\d)/g, "$1.$2");
}

function wrap(items, width) {
	const lines = [];
	let line = "";
	for (const item of items) {
		const next = line ? `${line}, ${item}` : item;
		if (next.length > width && line) {
			lines.push(`${line},`);
			line = item;
		} else {
			line = next;
		}
	}
	if (line) lines.push(line);
	return lines;
}

function main() {
	const catalog = fetchCatalog();
	const models = catalog.models;
	const incomplete = models.filter(needsLimits);

	const cached = rawFile
		? readFileSync(rawFile, "utf8").split(ROUND_SEPARATOR)
		: undefined;
	const { state, text } = probeRounds(incomplete, cached);
	if (saveFile) writeFileSync(saveFile, text);

	// Tier 2 evidence: a ceiling another gateway confirmed for the same model.
	// Tier 3: what a provider exe.dev does normalize declares for it. Tier 2 wins
	// over tier 3 because a normalized limit is that provider's own serving cap,
	// not the model's — fireworks caps most models at 16384 regardless.
	const probedByBase = new Map();
	const declaredByBase = new Map();
	for (const m of models) {
		const base = baseModel(m.native_id);
		const hit = state.get(m.id);
		if (hit?.maxTokens)
			probedByBase.set(
				base,
				Math.min(probedByBase.get(base) ?? Infinity, hit.maxTokens),
			);
		if (m.limits?.max_output_tokens)
			declaredByBase.set(
				base,
				Math.min(declaredByBase.get(base) ?? Infinity, m.limits.max_output_tokens),
			);
	}
	// Context is only ever guessed downward: these gateways truncate an oversized
	// request instead of rejecting it, so guessing high corrupts answers silently.
	const contextByBase = new Map();
	for (const m of models) {
		const base = baseModel(m.native_id);
		const value =
			state.get(m.id)?.contextWindow ??
			m.limits?.context_window ??
			m.upstream?.context_length;
		if (value)
			contextByBase.set(base, Math.min(contextByBase.get(base) ?? Infinity, value));
	}

	const rows = [];
	const unresolved = [];
	for (const m of incomplete) {
		const base = baseModel(m.native_id);
		const hit = state.get(m.id);
		// A published window is read at runtime, so only record a context
		// window the probe measured and that claim disagrees with, plus the
		// providers that publish no claim at all.
		const claimed = m.limits?.context_window ?? m.upstream?.context_length;
		const measured = hit?.contextWindow;
		const contextWindow =
			measured && measured !== claimed
				? measured
				: claimed
					? undefined
					: contextByBase.get(base);
		// A model cannot emit more tokens than its window holds, and declaring an
		// output cap it can never reach makes every long answer look like a
		// recoverable overflow to the agent, which compacts and retries for nothing.
		const window =
			contextWindow ?? claimed ?? contextByBase.get(base) ?? DEFAULT_CONTEXT_WINDOW;
		let maxTokens =
			hit?.maxTokens ??
			probedByBase.get(base) ??
			declaredByBase.get(base) ??
			MANUAL_MAX_TOKENS.get(base);
		if (maxTokens !== undefined) maxTokens = Math.min(maxTokens, window);
		if (maxTokens === undefined && contextWindow === undefined) {
			unresolved.push(
				`${m.provider}/${m.native_id}${hit?.accepted ? " (clamps)" : ""}`,
			);
			continue;
		}
		const fields = [];
		if (contextWindow !== undefined) fields.push(`contextWindow: ${contextWindow}`);
		if (maxTokens !== undefined) fields.push(`maxTokens: ${maxTokens}`);
		rows.push(`\t["${m.provider}\\0${m.native_id}", { ${fields.join(", ")} }],`);
	}

	rows.sort();
	console.log("// Real context and output ceilings for the models exe.dev ships incomplete");
	console.log("// `limits` for. Regenerate with scripts/probe-gateway-limits.mjs rather");
	console.log("// than editing by hand.");
	console.log("//");
	console.log("// A value is the ceiling the provider itself named and then honoured when we");
	console.log("// asked for exactly it; failing that, the lowest such ceiling another provider");
	console.log("// confirmed for the same model; failing that, the lowest limit a provider");
	console.log("// exe.dev does normalize declares for it. A probe beats a declared limit");
	console.log("// because a declared limit is that provider's own serving cap, not the");
	console.log("// model's. Lowest wins throughout: these providers truncate an oversized");
	console.log("// request instead of rejecting it, so guessing high corrupts answers silently");
	console.log("// while guessing low only wastes budget.");
	console.log("//");
	console.log(`// ${rows.length} of ${incomplete.length} models resolved against ${host}.`);
	console.log("const PROBED_LIMITS: ReadonlyMap<");
	console.log("\tstring,");
	console.log("\t{ contextWindow?: number; maxTokens?: number }");
	console.log("> = new Map([");
	for (const row of rows) console.log(row);
	console.log("]);");

	// Absent entries are a deliberate result, not an oversight: naming them here
	// keeps a later reader from re-probing models that have nothing to find.
	console.log("");
	console.log(`// The remaining ${unresolved.length} gateway models keep the defaults. Some accept any`);
	console.log("// max_tokens and clamp in silence, so their real ceiling never surfaces; the");
	console.log("// rest are off-plan, wrong-protocol, or unavailable, and cannot be asked:");
	for (const line of wrap(unresolved, 74)) console.log(`//   ${line}`);
	console.error(`unresolved (${unresolved.length}): ${unresolved.join(", ")}`);
}

main();
