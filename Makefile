IMAGE   ?= ghcr.io/danruto/pbuntu
TAG     ?= latest

default: build

# ── base ───────────────────────────────────────────────
build: ## Build the base pbuntu image (fork of exeuntu)
	@echo "=== base ==="
	docker build -t $(IMAGE):$(TAG) .

run: build
	docker run -it \
	  --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run \
	  --tmpfs /run/lock \
	  --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw \
	  $(IMAGE):$(TAG)

run-bash: build
	docker run -it \
	  --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run \
	  --tmpfs /run/lock \
	  --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw \
	  $(IMAGE):$(TAG) bash

# ── golang ─────────────────────────────────────────────
build-golang: build ## Build golang variant (requires base)
	@echo "=== golang ==="
	docker build -t $(IMAGE):golang -f variants/golang.Dockerfile .

run-golang: build-golang
	docker run -it --rm \
	  --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw \
	  $(IMAGE):golang

# ── rust ───────────────────────────────────────────────
build-rust: build ## Build rust+bun variant (requires base)
	@echo "=== rust ==="
	docker build -t $(IMAGE):rust -f variants/rust.Dockerfile .

run-rust: build-rust
	docker run -it --rm \
	  --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw \
	  $(IMAGE):rust

# ── web ────────────────────────────────────────────────
build-web: build ## Build bun web variant (requires base)
	@echo "=== web ==="
	docker build -t $(IMAGE):web -f variants/web.Dockerfile .

run-web: build-web
	docker run -it --rm \
	  --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw \
	  -p 3000:3000 \
	  $(IMAGE):web

# ── runner ─────────────────────────────────────────────
build-runner: ## Build minimal runner image
	@echo "=== runner ==="
	docker build -t $(IMAGE):runner -f variants/runner.Dockerfile .

run-runner: build-runner
	docker run -it --rm $(IMAGE):runner

build-runner-ssh: ## Build runner-ssh image (minimal SSH runtime for exe.dev VMs)
	@echo "=== runner-ssh ==="
	docker build -t $(IMAGE):runner-ssh -f variants/runner-ssh.Dockerfile .

run-runner-ssh: build-runner-ssh
	docker run -it --rm -p 2222:22 $(IMAGE):runner-ssh

# ── editor ─────────────────────────────────────────────
build-editor: build ## Build editor variant (requires base)
	@echo "=== editor ==="
	docker build -t $(IMAGE):editor -f variants/editor.Dockerfile .

run-editor: build-editor
	docker run -it --rm \
	  --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw \
	  -p 2222:22 \
	  $(IMAGE):editor

# ── ship ───────────────────────────────────────────────
# Script: scripts/ship — runs from any app repo, not just pbuntu.
#
# One-time registry setup:
#   make registry-create
#
# Deploy an app (the app repo has a Dockerfile):
#   scripts/ship myapp v2                    # VM auto-named myapp-v2
#   scripts/ship myapp v2 myapp-prod         # VM named myapp-prod
#   REGISTRY=my-registry.exe.xyz scripts/ship myapp v2
#
REGISTRY  ?= pb-registry.exe.xyz

registry-create: ## Create a private Docker registry VM on exe.dev (one-time)
	@scripts/ship registry-create

ship: ## Build + push + create an exe.dev VM (delegates to scripts/ship)
	@echo "Use scripts/ship directly from your app repo:"
	@echo "  scripts/ship <app> <tag> [vmname]"

# ── all ────────────────────────────────────────────────
build-all: build build-golang build-rust build-web build-runner build-runner-ssh build-editor ## Build everything

# ── misc ───────────────────────────────────────────────
clean: ## Remove all pbuntu images
	docker rmi $(IMAGE):$(TAG) $(IMAGE):golang $(IMAGE):rust $(IMAGE):web $(IMAGE):runner $(IMAGE):runner-ssh $(IMAGE):editor 2>/dev/null; true

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: default build build-golang build-rust build-web build-runner build-runner-ssh build-editor build-all
.PHONY: run run-bash run-golang run-rust run-web run-runner run-runner-ssh run-editor
.PHONY: ship clean help
