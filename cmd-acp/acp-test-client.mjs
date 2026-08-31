#!/usr/bin/env node
// Minimal ACP client driver to test cmd-acp end-to-end.
// Spawns the agent over stdio, does initialize/newSession/prompt,
// and prints the session/update notifications it receives.
import * as acp from "@agentclientprotocol/sdk";
import { spawn } from "node:child_process";
import { Readable, Writable } from "node:stream";

const agentCmd = process.argv[2] || "node";
const agentArgs = process.argv[3] ? [process.argv[3]] : [];
const cwd = process.argv[4] || process.cwd();

const child = spawn(agentCmd, agentArgs, {
  cwd,
  stdio: ["pipe", "pipe", "inherit"],
});

const input = Writable.toWeb(child.stdin);
const output = Readable.toWeb(child.stdout);
const stream = acp.ndJsonStream(input, output);

const app = acp.client({ name: "test-client" });
let sessionId = null;
let messageCount = 0;

app.onNotification("session/update", async (ctx) => {
  const update = ctx.params.update;
  messageCount++;
  if (update.sessionUpdate === "agent_message_chunk") {
    console.log(`[chunk] ${update.content.text}`);
  } else if (update.sessionUpdate === "tool_call") {
    console.log(`[tool_call] ${update.title} (${update.kind}, ${update.status})`);
  } else if (update.sessionUpdate === "tool_call_update") {
    console.log(`[tool_call_update] ${update.toolCallId} -> ${update.status}`);
  } else {
    console.log(`[update] ${JSON.stringify(update).slice(0, 200)}`);
  }
});

const conn = await app.connect(stream);

// 1. initialize
const init = await conn.agent.request("initialize", {
  protocolVersion: acp.PROTOCOL_VERSION,
  clientCapabilities: {},
  clientInfo: { name: "test-client", version: "1.0.0" },
});
console.log(`INIT protocolVersion=${init.protocolVersion} agentInfo=${JSON.stringify(init.agentInfo)}`);

// 2. new session
const ns = await conn.agent.request("session/new", { cwd, mcpServers: [] });
sessionId = ns.sessionId;
console.log(`NEW_SESSION ${sessionId}`);

// 3. prompt
const promptText = process.env.TEST_PROMPT || "Reply with exactly: pong";
console.log(`PROMPT: ${promptText}`);
let res = await conn.agent.request("session/prompt", {
  sessionId,
  prompt: [{ type: "text", text: promptText }],
});
console.log(`DONE stopReason=${res.stopReason} chunks=${messageCount}`);

// 4. second prompt — tests --continue chaining
const prompt2 = process.env.TEST_PROMPT2;
if (prompt2) {
  console.log(`PROMPT2: ${prompt2}`);
  const before = messageCount;
  res = await conn.agent.request("session/prompt", {
    sessionId,
    prompt: [{ type: "text", text: prompt2 }],
  });
  console.log(`DONE2 stopReason=${res.stopReason} chunks=${messageCount - before}`);
}

process.exit(0);
