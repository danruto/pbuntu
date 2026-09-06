#!/usr/bin/env node
// gen-cmd-providers — write configs/command-code/providers.json from the
// exe.dev gateway's own catalogue, so cmd's BYOK model list is the gateway's
// list and not a hand-copied snapshot that stops matching it.
//
//   scripts/gen-cmd-providers.mjs <ssh-host> [--check]
//   scripts/gen-cmd-providers.mjs --catalog models.json [--check]
//
// https://llm.int.exe.xyz is reachable only from inside an exe.dev VM, so the
// catalogue is read there over ssh; --catalog reads a saved copy instead.
// --check writes nothing and exits 1 when the committed file would change,
// naming the models that differ.
//
// Limits follow the precedence pi's integration_catalog.ts applies at
// runtime, PROBED_LIMITS included, so pi and cmd hold one ceiling per model.
// Re-run scripts/probe-gateway-limits.mjs first when the gateway adds models,
// or the new ones ship with whatever window the catalogue advertises.

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PROBED_LIMITS } from "../pi-extension/integration_catalog.ts";

const OUT = join(
	dirname(fileURLToPath(import.meta.url)),
	"..",
	"configs",
	"command-code",
	"providers.json",
);
const PROVIDER = "commandai";
// What integration_catalog.ts falls back to when nothing describes a window.
const DEFAULT_CONTEXT_WINDOW = 128000;

function positive(value) {
	return typeof value === "number" && Number.isFinite(value) && value > 0
		? value
		: undefined;
}

export function providersFromCatalog(catalog, probedLimits = PROBED_LIMITS) {
	const models = {};
	// cmd speaks the OpenAI chat wire to this provider, so a model the gateway
	// serves only over another protocol would be listed but never answer.
	const usable = catalog.models.filter(
		(m) => m.provider === PROVIDER && m.apis?.includes("openai_chat"),
	);
	for (const m of usable.sort((a, b) => (a.native_id < b.native_id ? -1 : 1))) {
		const probed = probedLimits.get(`${PROVIDER}\0${m.native_id}`);
		const contextWindow =
			positive(m.limits?.context_window) ??
			probed?.contextWindow ??
			positive(m.upstream?.context_length) ??
			DEFAULT_CONTEXT_WINDOW;
		const maxOutput =
			positive(m.limits?.max_output_tokens) ?? probed?.maxTokens;
		models[m.native_id] = {
			name: m.upstream?.name || m.native_id,
			contextWindow,
			// A model cannot emit more tokens than its window holds.
			...(maxOutput ? { maxOutput: Math.min(maxOutput, contextWindow) } : {}),
		};
	}
	return {
		provider: {
			"exe-llm": {
				name: "exe.dev LLM integration",
				api: "openai-completions",
				baseURL: `https://llm.int.exe.xyz/${PROVIDER}/v1`,
				apiKey: false,
				models,
			},
		},
	};
}

function modelIDs(text) {
	return Object.keys(JSON.parse(text).provider["exe-llm"].models);
}

function main() {
	const args = process.argv.slice(2);
	const check = args.includes("--check");
	const catalogIndex = args.indexOf("--catalog");
	const catalogFile = catalogIndex === -1 ? undefined : args[catalogIndex + 1];
	const host = args.find(
		(a) => !a.startsWith("--") && a !== catalogFile,
	);
	if (!catalogFile && !host) {
		console.error(
			"usage: gen-cmd-providers.mjs <ssh-host> [--check] | --catalog models.json [--check]",
		);
		process.exit(2);
	}

	const catalog = JSON.parse(
		catalogFile
			? readFileSync(catalogFile, "utf8")
			: execFileSync(
					"ssh",
					[
						"-o",
						"BatchMode=yes",
						"-n",
						host,
						"curl -sS --max-time 60 https://llm.int.exe.xyz/models.json",
					],
					{ encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
				),
	);
	const next = `${JSON.stringify(providersFromCatalog(catalog), null, 2)}\n`;
	const current = existsSync(OUT) ? readFileSync(OUT, "utf8") : "";

	if (!check) {
		writeFileSync(OUT, next);
		console.log(`wrote ${modelIDs(next).length} models to ${OUT}`);
		return;
	}
	if (current === next) {
		console.log(`${OUT} matches the gateway`);
		return;
	}
	const before = new Set(current ? modelIDs(current) : []);
	const after = new Set(modelIDs(next));
	const added = [...after].filter((id) => !before.has(id));
	const removed = [...before].filter((id) => !after.has(id));
	console.error(`${OUT} is stale`);
	if (added.length) console.error(`  added on the gateway:\n    ${added.join("\n    ")}`);
	if (removed.length) console.error(`  gone from the gateway:\n    ${removed.join("\n    ")}`);
	if (!added.length && !removed.length)
		console.error("  same models, different limits or names");
	console.error("regenerate with scripts/gen-cmd-providers.mjs <ssh-host>");
	process.exit(1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
