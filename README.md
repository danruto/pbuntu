# pbuntu

VM images for the [exe.dev](https://exe.dev) fleet that [pbctrl](https://github.com/danruto/pbctrl)
drives. Published to `ghcr.io/danruto/pbuntu` by GitHub Actions on every push to `main`.

Two images, built thin on purpose: exe.dev meters pooled filesystem usage across the account, so
every megabyte in an image is paid once per VM that boots it.

| Tag | Built from | Boots |
|---|---|---|
| `latest`, `<sha>` | `Dockerfile` | the control plane, the hub VM (herdr client), every runner |
| `dev-<toolchains>-<sha>` | `variants/dev.Dockerfile` | one shared development machine per toolchain set |

## Base

Ubuntu with systemd as init, sshd, Docker + Compose, Tailscale, git, `gh`, `jq`, ripgrep and `just`.
Nothing else: no editors, no language toolchains, no coding agents. It boots with `tailscaled`,
`docker` and `ssh` enabled so the control plane's first SSH finds every daemon it needs.

## Dev

The base plus what a coding agent needs: node (as a harness dependency, not a toolchain), Claude
Code, pi with its extensions, Command Code with the `cmd-acp` bridge, and the herdr server the
control plane dispatches through. Language toolchains come from the `TOOLCHAINS` build arg, a
comma-separated subset of `go,rust,bun`, and the tag names the set the way the control plane names
the machine that boots it: `dev-rust-bun-<sha>` boots `dev-rust-bun`.

`publish.yml` builds one image per entry in its `toolchains` matrix. A project that declares a
combination no entry covers needs one added there.

A dev machine is shared by every project that declares its toolchain set; each project's checkout
is at `/home/exedev/<project>`. `pb-slim` on the machine lists what can still be dropped by hand
(a playwright download, the npm cache).

## Build locally

```sh
make build                          # base
make build-dev TOOLCHAINS=rust,bun  # one dev variant
make size                           # what each came to
make run-dev                        # boot it under docker with systemd
```

## Agent configuration sync

The dev image ships the mechanism for pulling an operator's own agent configuration onto a VM and
none of the configuration itself. Provide `/exe.dev/agent-config.env` listing the repositories:

```dotenv
AGENT_CONFIG_REPOS=you/one-repo you/another
# Optional, the global agent instructions, in whichever repo carries them:
AGENT_CONFIG_INSTRUCTIONS=path/within/the/repo/CLAUDE.md
# Optional, defaults to exe.dev's GitHub proxy:
AGENT_GIT_HOST=https://github.int.exe.xyz
```

`agent-config.service` clones each repository in order and inspects it for things a harness
understands:

- `.claude-plugin/marketplace.json` → registers the checkout as a local Claude Code marketplace and
  installs every plugin the manifest lists;
- `plugins/*/instructions` and its sibling `standards/` → copied into `~/.pi/agent/skills/<repo>/`;
- `AGENT_CONFIG_INSTRUCTIONS`, if that path exists in the repo → merged ahead of this image's own
  `AGENTS.md` into the single file `~/.claude/CLAUDE.md` and `~/.pi/AGENTS.md` both point at.

The env file is kept rather than consumed, so every boot re-syncs from it. The credential is
whatever gives the VM read access to those repositories — on exe.dev, a readonly GitHub
integration attached to the VM.

## Upstream

A fork of [boldsoftware/exeuntu](https://github.com/boldsoftware/exeuntu), exe.dev's default image.
The exe.dev boot contract it keeps: the `exe.dev/login-user` label, an `exedev` user with UID 1000
and passwordless sudo, systemd reached through `/usr/local/bin/init`, and `/exe.dev/setup` run once
on first boot.
