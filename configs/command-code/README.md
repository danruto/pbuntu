# command-code providers

BYOK provider config for the `cmd` CLI, baked into the dev image at
`~/.commandcode/providers.json`.

The `exe-llm` provider points at the exe.dev LLM integration gateway
(`commandai` route). It is keyless: the gateway is reachable only from inside
an exe.dev VM and needs no API key there.

Model ids and limits come from the gateway's own catalog
(`https://llm.int.exe.xyz/models.json`) — see
`scripts/probe-gateway-limits.mjs` for how the real ceilings are measured.
`contextWindow`/`maxOutput` are the ceilings the gateway itself honours.

The dev image also bakes two runtime settings alongside the provider config:

- `~/.commandcode/config.json` — `{"localOnly": true}` keeps cmd off the
  Command Code backend; all traffic goes to the gateway.
- `export COMMAND_CODE_API_KEY=exe-gateway` prepended to `~/.bashrc`, above
  the interactive guard, so pb-executor's non-interactive shells (which
  source `~/.bashrc` and return at the guard) still set the gateway key.
