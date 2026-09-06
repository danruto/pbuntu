IMAGE      ?= ghcr.io/danruto/pbuntu
TAG        ?= latest
TOOLCHAINS ?= go,rust,bun

default: build

RUN_FLAGS = --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw

# ── base ───────────────────────────────────────────────
build: ## Build the base image every fleet VM boots from
	@echo "=== base ==="
	docker build -t $(IMAGE):$(TAG) .

run: build
	docker run -it --rm $(RUN_FLAGS) -p 2222:22 $(IMAGE):$(TAG)

run-bash: build
	docker run -it --rm $(RUN_FLAGS) $(IMAGE):$(TAG) bash

# ── dev ────────────────────────────────────────────────
# One dev image per toolchain set. The tag names the set the way the control
# plane names the machine that boots it: dev-<toolchains joined by '-'>.
dev_tag = dev-$(subst $(eval) ,-,$(subst $(comma), ,$(TOOLCHAINS)))
comma := ,

build-dev: build ## Build a dev variant for TOOLCHAINS (default go,rust,bun)
	@echo "=== $(dev_tag) ==="
	docker build -t $(IMAGE):$(dev_tag) --build-arg TOOLCHAINS=$(TOOLCHAINS) -f variants/dev.Dockerfile .

run-dev: build-dev
	docker run -it --rm $(RUN_FLAGS) -p 2222:22 $(IMAGE):$(dev_tag)

size: ## Print the size of every locally built pbuntu image
	docker images $(IMAGE) --format '{{.Tag}}\t{{.Size}}'

# ── ship ───────────────────────────────────────────────
# Script: scripts/ship — runs from any app repo, not just pbuntu.
REGISTRY  ?= pb-registry.exe.xyz

registry-create: ## Create a private Docker registry VM on exe.dev (one-time)
	@scripts/ship registry-create

ship: ## Build + push + create an exe.dev VM (delegates to scripts/ship)
	@echo "Use scripts/ship directly from your app repo:"
	@echo "  scripts/ship <app> <tag> [vmname]"

# ── misc ───────────────────────────────────────────────
clean: ## Remove all locally built pbuntu images
	docker images $(IMAGE) -q | sort -u | xargs -r docker rmi -f

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: default build run run-bash build-dev run-dev size registry-create ship clean help
