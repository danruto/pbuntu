# pbuntu

> A personal fork of [exeuntu](https://github.com/boldsoftware/exeuntu) tuned for my workflow.
> exeuntu is the default base image for [exe.dev](https://exe.dev/) — a kitted-out developer
> image based on ubuntu 24.04 with systemd.

Available at `ghcr.io/danruto/pbuntu`.

## What's different from upstream exeuntu

- Tweaked package selection and tooling for my personal dev setup.
- Custom AGENTS.md and pi extension configuration.
- Otherwise tracks upstream closely.

## Build & run

```sh
make build     # build base image
make run       # build + run with systemd
make run-bash  # build + run, drop into bash
```

Variants: `make build-golang`, `build-rust`, `build-web`, `build-editor`.

## BB fleet enrollment

All non-runtime variants include BB's host daemon. The `runner` and `runner-ssh`
variants stay minimal and do not include it.

To enroll a project VM automatically, provide `/exe.dev/bb.env` before first
boot with the private server's generated machine-join values:

```dotenv
BB_SERVER=https://bb.example.com
BB_JOIN_CODE=...
BB_HOST_ID=...
# Optional when using bb connect:
BB_MACHINE_CODE=...
# Optional:
# BB_HOST_DAEMON_PORT=38887
```

The enabled `bb-enroll.service` consumes that file, joins the VM as a BB
execution machine, installs the matching host daemon, and removes the join file.
Credentials are runtime-provided and never baked into the image.

For a private self-hosted control machine, keep BB on loopback and publish it
through Tailscale Serve:

```bash
npx bb-app@latest
tailscale serve --bg --https=443 http://127.0.0.1:38886
```

Use the resulting private tailnet HTTPS URL as `BB_SERVER`, then generate the
machine join values from the control server's Settings → Machines. Do not use
Tailscale Funnel or expose BB on a public interface.

## Agent configuration sync

The image ships the mechanism for pulling an operator's own agent configuration
onto a VM and none of the configuration itself. These images are shared; the
repositories they sync usually are not, so nothing operator-specific is baked in.

Provide `/exe.dev/agent-config.env` listing the repositories:

```dotenv
AGENT_CONFIG_REPOS=you/one-repo you/another
# Optional, the global agent instructions, in whichever repo carries them:
AGENT_CONFIG_INSTRUCTIONS=path/within/the/repo/CLAUDE.md
# Optional, defaults to exe.dev's GitHub proxy:
AGENT_GIT_HOST=https://github.int.exe.xyz
```

There are no roles in that list — the unit does not know what any repository is
"for". It clones each one in order and inspects it for things a harness
understands:

- `.claude-plugin/marketplace.json` → registers the checkout as a local Claude
  Code marketplace and installs every plugin the manifest lists, by the names
  the manifest gives;
- `plugins/*/instructions` and its sibling `standards/` → copied into
  `~/.pi/agent/skills/<repo>/` for pi;
- `AGENT_CONFIG_INSTRUCTIONS`, if that path exists in the repo → merged ahead of
  this image's own `AGENTS.md` into the single file `~/.claude/CLAUDE.md`,
  `~/.codex/AGENTS.md` and `~/.pi/AGENTS.md` all point at. First repository in
  the list carrying it wins.

A repository offering none of these is cloned and nothing more.

The env file is kept rather than consumed: it names repositories and carries no
credential, so every boot re-syncs from it. The credential is whatever gives the
VM read access to those repositories — on exe.dev, a readonly GitHub integration
attached to the VM. Without one the unit fails and the VM is left exactly as the
image built it; `systemctl status agent-config` says which step failed.

## Upstream

This is a fork of [boldsoftware/exeuntu](https://github.com/boldsoftware/exeuntu).
See upstream for the original README, contributing guide, and full changelog.
