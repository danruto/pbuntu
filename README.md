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

## Upstream

This is a fork of [boldsoftware/exeuntu](https://github.com/boldsoftware/exeuntu).
See upstream for the original README, contributing guide, and full changelog.
