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

## Upstream

This is a fork of [boldsoftware/exeuntu](https://github.com/boldsoftware/exeuntu).
See upstream for the original README, contributing guide, and full changelog.
