#!/usr/bin/env node
// cmd-acp — minimal ACP (Agent Client Protocol) server around the command-code CLI.
//
// Speaks ACP v1 over stdio (JSON-RPC 2.0, newline-delimited) and drives `cmd`
// in headless mode per prompt turn:
//
//   - each ACP session maps 1:1 to a command-code headless session;
//   - `cmd -p "…" --output-format json` emits NDJSON: {type:"event",…} frames
//     (tool_running, etc.) then a final {type:"result",…} line;
//   - we translate those events into ACP session/update notifications
//     (agent_message_chunk, tool_call, tool_call_update) and finish the turn
//     when the result line arrives;
//   - later prompts continue the same command-code session (--continue) so
//     conversation context is preserved;
//   - the model catalog comes from `cmd --list-models` and is advertised on
//     session/new, because paseo refuses to create an agent whose --model the
//     provider does not list; `session/set_model` then picks the one each
//     `cmd -p` turn runs with.
//
// Register the result as a paseo ACP provider:
//
//   "agents": { "providers": {
//     "command-code": {
//       "extends": "acp",
//       "label": "Command Code",
//       "command": ["/usr/local/bin/cmd-acp"]
//     }
//   }}
//
// This is intentionally minimal: no auth flow, no permission prompts (the
// underlying CLI runs with --yolo), no session listing/resume. It exists to
// make command-code usable from paseo; treat it as a starting point.

import * as acp from "@agentclientprotocol/sdk";
import { spawn } from "node:child_process";
import { Readable, Writable } from "node:stream";

const CMD_BIN = process.env.CMD_ACP_CMD || "cmd";

// Extra flags for every `cmd -p` invocation. --yolo lets the agent write
// files/run commands without a TTY permission prompt; --trust and
// --skip-onboarding avoid first-run interactive prompts. Override via
// CMD_ACP_FLAGS (space-separated) if you want a stricter policy.
const CMD_FLAGS = (process.env.CMD_ACP_FLAGS || "--yolo --trust --skip-onboarding")
  .trim()
  .split(/\s+/)
  .filter(Boolean);

// Model ids for the catalog, comma-separated, first one the default. Set to
// bypass `cmd --list-models` on a host where that table is unavailable.
const CMD_MODELS_OVERRIDE = (process.env.CMD_ACP_MODELS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

function log(...args) {
  // stderr only — stdout is the ACP channel.
  console.error("[cmd-acp]", ...args);
}

// ---------------------------------------------------------------------------
// command-code subprocess helper
// ---------------------------------------------------------------------------

// Run one `cmd -p` turn. `continueFrom` is an optional command-code session id
// to resume (--continue). Returns { lines } where lines is the full NDJSON
// stdout (event + result frames) — the caller drives the notification stream.
function runCmdTurn({ prompt, cwd, continueFrom, model }) {
  return new Promise((resolve, reject) => {
    const args = [
      "-p",
      prompt,
      "--output-format",
      "json",
      ...CMD_FLAGS,
    ];
    if (model) {
      args.push("--model", model);
    }
    if (continueFrom) {
      args.push("--continue");
    }

    log(`spawn ${CMD_BIN} ${args.join(" ")} (cwd=${cwd})`);
    const child = spawn(CMD_BIN, args, {
      cwd,
      env: process.env,
      stdio: ["ignore", "pipe", "inherit"],
    });

    let stdoutBuf = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdoutBuf += chunk;
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(`${CMD_BIN} exited with code ${code}`));
        return;
      }
      resolve({ stdout: stdoutBuf });
    });
  });
}

// The catalog paseo validates --model against. `cmd --list-models` prints a
// human table: one `<provider>/<id>  <description>` row per model, the default
// row's description ending in "(default)". Rows without a slash are section
// headings. Resolved once per process; an empty result advertises nothing.
let modelCatalog = null;
function listModels() {
  if (modelCatalog) return modelCatalog;
  modelCatalog = (async () => {
    if (CMD_MODELS_OVERRIDE.length) {
      return {
        currentModelId: CMD_MODELS_OVERRIDE[0],
        availableModels: CMD_MODELS_OVERRIDE.map((modelId) => ({ modelId, name: modelId })),
      };
    }
    let stdout = "";
    try {
      stdout = await new Promise((resolve, reject) => {
        const child = spawn(CMD_BIN, ["--list-models"], { env: process.env, stdio: ["ignore", "pipe", "inherit"] });
        let buf = "";
        child.stdout.setEncoding("utf8");
        child.stdout.on("data", (chunk) => (buf += chunk));
        child.on("error", reject);
        child.on("close", () => resolve(buf));
      });
    } catch (err) {
      log("model listing failed:", err.message);
    }
    const availableModels = [];
    let currentModelId = null;
    for (const line of stdout.split("\n")) {
      const match = /^(\S+\/\S+)\s{2,}(.*)$/.exec(line.trim());
      if (!match) continue;
      const [, modelId, description] = match;
      availableModels.push({ modelId, name: modelId, description });
      if (/\(default\)\s*$/.test(description)) currentModelId = modelId;
    }
    if (!currentModelId && availableModels.length) currentModelId = availableModels[0].modelId;
    log(`model catalog: ${availableModels.length} models, default ${currentModelId}`);
    return { currentModelId, availableModels };
  })();
  return modelCatalog;
}

// Parse the NDJSON output into a list of frames.
function parseFrames(stdout) {
  const frames = [];
  for (const line of stdout.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      frames.push(JSON.parse(trimmed));
    } catch {
      log("skipping non-JSON output line:", trimmed.slice(0, 200));
    }
  }
  return frames;
}

// Map a command-code tool name to an ACP ToolKind.
function toolKindFor(toolName) {
  const name = (toolName || "").toLowerCase();
  if (name.startsWith("read") || name.includes("search") || name.includes("grep") || name.includes("list")) return "read";
  if (name.startsWith("write") || name.includes("edit") || name.includes("patch")) return "edit";
  if (name.includes("delete") || name.includes("rm") || name.includes("remove")) return "delete";
  if (name.includes("move") || name.includes("rename")) return "move";
  if (name.startsWith("shell") || name.includes("bash") || name.includes("exec") || name.includes("run")) return "execute";
  if (name.includes("fetch") || name.includes("web") || name.includes("http") || name.includes("url")) return "fetch";
  if (name.includes("think") || name.includes("plan")) return "think";
  return "other";
}

// Extract a file path from a raw tool input object, if any — for locations.
function locationFromInput(rawInput) {
  if (!rawInput || typeof rawInput !== "object") return undefined;
  const path = rawInput.file_path || rawInput.path || rawInput.filename;
  if (typeof path === "string" && path.startsWith("/")) return path;
  return undefined;
}

// ---------------------------------------------------------------------------
// ACP agent
// ---------------------------------------------------------------------------

class CmdAcpAgent {
  constructor() {
    // ACP sessionId -> { cwd, cmdSessionId, activeRun }
    this.sessions = new Map();
  }

  async initialize(params) {
    return {
      protocolVersion: acp.PROTOCOL_VERSION,
      agentCapabilities: {
        // Minimal: text-only prompts, no session listing/loading.
        loadSession: false,
      },
      agentInfo: {
        name: "cmd-acp",
        title: "Command Code (via cmd-acp)",
        version: "0.1.0",
      },
    };
  }

  async newSession(params) {
    const sessionId = randomId();
    const cwd = params.cwd || process.cwd();
    const models = await listModels();
    this.sessions.set(sessionId, {
      id: sessionId,
      cwd,
      cmdSessionId: null,
      activeRun: null,
      model: models.currentModelId,
    });
    log(`new session ${sessionId} cwd=${cwd}`);
    // `models` is ACP's unstable model-state extension; paseo reads it to
    // build the provider catalog and to know which selection it starts from.
    return models.availableModels.length ? { sessionId, models } : { sessionId };
  }

  async setModel(params) {
    const session = this.sessions.get(params.sessionId);
    if (!session) {
      throw new acp.RequestError(-32002, `Session ${params.sessionId} not found`);
    }
    const models = await listModels();
    if (!models.availableModels.some((m) => m.modelId === params.modelId)) {
      throw new acp.RequestError(-32602, `Unknown model ${params.modelId}`);
    }
    session.model = params.modelId;
    log(`session ${session.id} model=${session.model}`);
    return {};
  }

  async authenticate() {
    // No auth — command-code's own credentials are used by the CLI.
    return {};
  }

  async prompt(params, cx) {
    const session = this.sessions.get(params.sessionId);
    if (!session) {
      throw new acp.RequestError(-32002, `Session ${params.sessionId} not found`);
    }

    const text = promptToText(params.prompt);
    if (!text) {
      // Nothing to say.
      return { stopReason: "end_turn" };
    }

    const controller = new AbortController();
    session.activeRun = controller;

    try {
      // Stream the run: translate cmd's NDJSON events into ACP updates.
      const { stdout } = await runCmdTurn({
        prompt: text,
        cwd: session.cwd,
        continueFrom: session.cmdSessionId,
        model: session.model,
      });
      const frames = parseFrames(stdout);
      const result = await this.emitFrames(session, frames, cx, controller.signal);

      // Remember the command-code session for the next turn.
      if (result?.sessionId) {
        session.cmdSessionId = result.sessionId;
      }

      return {
        stopReason: result?.subtype === "error" ? "refusal" : "end_turn",
      };
    } catch (err) {
      if (controller.signal.aborted) {
        return { stopReason: "cancelled" };
      }
      throw err;
    } finally {
      session.activeRun = null;
    }
  }

  // Translate the cmd NDJSON frames into ACP session/update notifications.
  // Returns the final result frame.
  async emitFrames(session, frames, cx, abortSignal) {
    let result = null;
    let messageId = null;

    for (const frame of frames) {
      if (abortSignal.aborted) break;

      if (frame.type === "event") {
        const ev = frame.event;
        if (!ev) continue;

        switch (ev.type) {
          case "text_delta":
            // Streaming assistant text.
            if (typeof ev.delta === "string" && ev.delta.length > 0) {
              if (!messageId) messageId = randomId();
              await cx.notify(acp.methods.client.session.update, {
                sessionId: session.id,
                update: {
                  sessionUpdate: "agent_message_chunk",
                  content: { type: "text", text: ev.delta },
                  messageId,
                },
              });
            }
            break;

          case "tool_queued":
          case "tool_running": {
            // A tool call starts (queued -> pending, running -> in_progress).
            const toolCallId = ev.toolCallId || randomId();
            const title = ev.toolName || ev.description || "tool";
            const rawInput = ev.input;
            const loc = locationFromInput(rawInput);
            await cx.notify(acp.methods.client.session.update, {
              sessionId: session.id,
              update: {
                sessionUpdate: "tool_call",
                toolCallId,
                title,
                kind: toolKindFor(ev.toolName),
                status: ev.type === "tool_queued" ? "pending" : "in_progress",
                rawInput,
                locations: loc ? [{ path: loc }] : undefined,
              },
            });
            break;
          }

          case "tool_completed": {
            const toolCallId = ev.toolCallId || randomId();
            const rawOutput = Array.isArray(ev.result)
              ? ev.result
                  .map((r) => (r && r.type === "text" ? r.text : ""))
                  .join("\n")
              : ev.result;
            await cx.notify(acp.methods.client.session.update, {
              sessionId: session.id,
              update: {
                sessionUpdate: "tool_call_update",
                toolCallId,
                status: "completed",
                rawOutput,
              },
            });
            break;
          }

          case "run_end": {
            // The run finished; the session id for chaining lives in the
            // result payload (and is repeated on the top-level result line).
            if (ev.result && typeof ev.result === "object") {
              result = ev.result;
            }
            break;
          }

          default:
            // Unknown event types are forward-compatible; ignore.
            log("ignoring event type:", ev.type);
        }
      } else if (frame.type === "result") {
        result = frame;
      }
    }

    // Send the final answer as the last chunk if it isn't already streamed.
    const finalText = result?.finalText;
    if (finalText && !abortSignal.aborted) {
      await cx.notify(acp.methods.client.session.update, {
        sessionId: session.id,
        update: {
          sessionUpdate: "agent_message_chunk",
          content: { type: "text", text: finalText },
          messageId: messageId || randomId(),
        },
      });
    }

    return result;
  }

  async cancel(params) {
    const session = this.sessions.get(params.sessionId);
    if (session?.activeRun) {
      session.activeRun.abort();
    }
  }
}

function promptToText(prompt) {
  if (!Array.isArray(prompt)) return "";
  return prompt
    .map((block) => {
      if (block?.type === "text") return block.text ?? "";
      if (block?.type === "resource_link") return block.uri ?? "";
      if (block?.type === "resource") {
        const res = block.resource;
        if (res?.type === "text") return res.text ?? "";
        return res?.uri ?? "";
      }
      return "";
    })
    .join("\n")
    .trim();
}

function randomId() {
  return Array.from(crypto.getRandomValues(new Uint8Array(16)))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// ---------------------------------------------------------------------------
// Wire up the stdio transport
// ---------------------------------------------------------------------------

const HELP = `cmd-acp — minimal ACP (Agent Client Protocol) server around the command-code CLI.

Usage:
  cmd-acp                Run the ACP server over stdio (what paseo launches)
  cmd-acp --help         Show this help
  cmd-acp --version      Print the version

Environment:
  CMD_ACP_CMD            command-code binary (default: cmd)
  CMD_ACP_FLAGS          extra flags for every cmd -p run
                         (default: --yolo --trust --skip-onboarding)
  CMD_ACP_MODELS         comma-separated model ids to advertise instead of
                         parsing \`cmd --list-models\`; the first is the default
`;

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  process.stdout.write(HELP);
  process.exit(0);
}
if (process.argv.includes("--version") || process.argv.includes("-v")) {
  process.stdout.write("cmd-acp 0.1.0\n");
  process.exit(0);
}

const input = Writable.toWeb(process.stdout);
const output = Readable.toWeb(process.stdin);
const stream = acp.ndJsonStream(input, output);

const agentImpl = new CmdAcpAgent();

acp
  .agent({ name: "cmd-acp" })
  .onRequest("initialize", (ctx) => agentImpl.initialize(ctx.params))
  .onRequest("session/new", (ctx) => agentImpl.newSession(ctx.params))
  .onRequest("authenticate", (ctx) => agentImpl.authenticate(ctx.params))
  .onRequest("session/prompt", (ctx) =>
    agentImpl.prompt(ctx.params, ctx.client),
  )
  // Not in the SDK's method table yet, so it needs its own params parser.
  .onRequest("session/set_model", (params) => params, (ctx) =>
    agentImpl.setModel(ctx.params),
  )
  .onNotification("session/cancel", (ctx) => agentImpl.cancel(ctx.params))
  .connect(stream);

log("ready");
