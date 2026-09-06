import assert from "node:assert/strict";
import { test } from "node:test";
import { providersFromCatalog } from "./gen-cmd-providers.mjs";

const model = (native_id, extra = {}) => ({
	id: `commandai/${native_id}`,
	provider: "commandai",
	native_id,
	apis: ["openai_chat"],
	limits: null,
	upstream: { name: `${native_id} name`, context_length: 1000000 },
	...extra,
});

test("limits: published beats probed beats advertised, and output never exceeds the window", () => {
	const probed = new Map([
		["commandai\0probed", { maxTokens: 2000 }],
		["commandai\0published", { contextWindow: 1, maxTokens: 1 }],
		["commandai\0capped", { maxTokens: 999999999 }],
	]);
	const { provider } = providersFromCatalog(
		{
			models: [
				model("probed"),
				model("published", {
					limits: { context_window: 500, max_output_tokens: 100 },
				}),
				model("capped", { upstream: { context_length: 300 } }),
				model("bare"),
			],
		},
		probed,
	);
	const models = provider["exe-llm"].models;
	assert.deepEqual(models.probed, {
		name: "probed name",
		contextWindow: 1000000,
		maxOutput: 2000,
	});
	assert.deepEqual(models.published, {
		name: "published name",
		contextWindow: 500,
		maxOutput: 100,
	});
	assert.equal(models.capped.maxOutput, 300);
	assert.deepEqual(models.bare, { name: "bare name", contextWindow: 1000000 });
});

test("only commandai models on the OpenAI chat wire are listed, in id order", () => {
	const { provider } = providersFromCatalog(
		{
			models: [
				model("b"),
				model("a"),
				model("responses-only", { apis: ["openai_responses"] }),
				model("elsewhere", { provider: "opencode-go" }),
			],
		},
		new Map(),
	);
	assert.deepEqual(Object.keys(provider["exe-llm"].models), ["a", "b"]);
	assert.equal(provider["exe-llm"].apiKey, false);
	assert.equal(
		provider["exe-llm"].baseURL,
		"https://llm.int.exe.xyz/commandai/v1",
	);
});
