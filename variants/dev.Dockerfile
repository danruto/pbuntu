# Dev variant — a shared development machine for every project that needs the
# same toolchains. One image is built per toolchain set (TOOLCHAINS, a
# comma-separated subset of go,rust,bun), so a machine carries exactly the
# compilers its projects use and nothing it would only ever delete.
#
# Everything a coding agent needs rides on top of the base: node for the
# harnesses that are npm packages, Claude Code, pi, Command Code with its ACP
# bridge, and the herdr server the control plane dispatches through.
#
# Build:  make build-dev TOOLCHAINS=rust,bun
#
FROM docker.io/library/golang:1.27.1 AS exeuntu-cli
ARG EXEUNTU_GIT_VERSION=unknown
WORKDIR /src/exeuntu-cli
COPY cli/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -mod=mod -tags osusergo,netgo \
        -ldflags "-X main.gitVersion=${EXEUNTU_GIT_VERSION} -extldflags=-static -s -w" \
        -o /out/exeuntu .

FROM ghcr.io/danruto/pbuntu:latest

ARG TOOLCHAINS=go,rust,bun

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# build-essential and pkg-config serve every toolchain: cargo links through cc,
# bun's native addons and node-gyp need make and a C++ compiler. libssl-dev is
# the one C library nearly every Rust and Node project ends up linking.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential pkg-config libssl-dev sqlite3 file lsof psmisc && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*

COPY --from=exeuntu-cli /out/exeuntu /usr/local/bin/exeuntu

# Node is a harness dependency, not a project toolchain: pi and command-code
# are npm packages. herdr is a static binary and needs none of it.
# Keep npm's global prefix user-writable: pi's self-updater runs as exedev.
RUN ARCH="$(uname -m)" && \
    case "${ARCH}" in x86_64) NODE_ARCH=x64 ;; aarch64|arm64) NODE_ARCH=arm64 ;; *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; esac && \
    NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.version | startswith("v24."))][0].version') && \
    curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" | \
        tar -xJC /usr/local --strip-components=1 --exclude='*/README.md' --exclude='*/LICENSE' --exclude='*/CHANGELOG.md' \
            --exclude='*/share' --exclude='*/include' && \
    node --version && npm --version
ENV NPM_CONFIG_PREFIX="/home/exedev/.local"
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# ── toolchains ────────────────────────────────────────────────────────────
# Go — latest stable from go.dev
RUN if [[ ",${TOOLCHAINS}," == *,go,* ]]; then \
        ARCH=$(dpkg --print-architecture) && \
        GO_VERSION=$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[0].version') && \
        curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -xzC /usr/local && \
        rm -rf /usr/local/go/test /usr/local/go/doc /usr/local/go/api && \
        ln -sf /usr/local/go/bin/go /usr/local/bin/go && \
        ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt && \
        go version && \
        mkdir -p /home/exedev/go/bin && chown -R exedev:exedev /home/exedev/go && \
        echo 'export PATH="$HOME/go/bin:$PATH"' >> /home/exedev/.bashrc; \
    fi

# Bun — system-wide so exedev and systemd units both find it
RUN if [[ ",${TOOLCHAINS}," == *,bun,* ]]; then \
        curl -fsSL https://bun.sh/install | env BUN_INSTALL=/usr/local bash && \
        bun --version; \
    fi

# Rust — rustup minimal profile; nextest from a prebuilt binary rather than a
# cargo install that would compile it on every image build.
USER exedev
RUN if [[ ",${TOOLCHAINS}," == *,rust,* ]]; then \
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
            --profile minimal --default-toolchain stable -c rustfmt -c clippy && \
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /home/exedev/.bashrc && \
        . /home/exedev/.cargo/env && \
        case "$(uname -m)" in \
            x86_64) NEXTEST_URL=https://get.nexte.st/latest/linux ;; \
            aarch64|arm64) NEXTEST_URL=https://get.nexte.st/latest/linux-arm ;; \
            *) echo "Unsupported architecture: $(uname -m)" && exit 1 ;; \
        esac && \
        curl -fsSL "${NEXTEST_URL}" | tar -xzC /home/exedev/.cargo/bin && \
        cargo nextest --version && \
        rm -rf /home/exedev/.rustup/toolchains/*/share/doc; \
    fi
USER root

# ── coding agents ─────────────────────────────────────────────────────────
RUN mkdir -p /home/exedev/.claude /home/exedev/.pi /home/exedev/.config && \
    chown -R exedev:exedev /home/exedev/.claude /home/exedev/.pi /home/exedev/.config

# The image's own agent instructions live outside $HOME: agent-config-sync
# merges the operator's ahead of them into ~/.config/agents/AGENTS.md and
# repoints these links there, and a source inside that tree would be truncated
# by its own merge.
COPY AGENTS.md /etc/agents/AGENTS.md
RUN chmod 644 /etc/agents/AGENTS.md && \
    ln -s /etc/agents/AGENTS.md /home/exedev/.claude/CLAUDE.md && \
    ln -s /etc/agents/AGENTS.md /home/exedev/.pi/AGENTS.md

RUN exeuntu update claude && \
    test -x /usr/local/bin/claude && \
    /usr/local/bin/claude --version

# pi lands in the user-writable prefix: `pi update --self` writes where it is
# installed.
ARG PI_VERSION=
USER exedev
RUN if [ -n "${PI_VERSION}" ]; then \
        npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}"; \
    else \
        npm install -g --ignore-scripts @earendil-works/pi-coding-agent; \
    fi && \
    test -x /home/exedev/.local/bin/pi && \
    /home/exedev/.local/bin/pi --version && \
    export PATH="/home/exedev/.local/bin:$PATH" && \
    pi install npm:pi-ponytail && \
    pi install npm:cc-safety-net && \
    pi install npm:pi-web-access && \
    pi install npm:pi-hermes-memory && \
    pi list | grep -q pi-hermes-memory && \
    rm -rf /home/exedev/.npm/_cacache
USER root
RUN ln -sf /home/exedev/.local/bin/pi /usr/local/bin/pi

# pi-hermes-memory's background reviews go to the gateway's cheap route, not
# the user's default chat model.
RUN printf '%s\n' '{"llmModelOverride":"exe-dev-fireworks/accounts/fireworks/models/deepseek-v4-flash-0731@llm","llmThinkingOverride":"off"}' \
      > /home/exedev/.pi/agent/hermes-memory-config.json && \
    jq -e .llmModelOverride /home/exedev/.pi/agent/hermes-memory-config.json > /dev/null

# The pi exe.dev extension. The bundled catalog supplies pricing and
# compatibility metadata only; reflection-discovered integrations supply every
# model and provider route.
COPY pi-extension/ /home/exedev/.pi/agent/extensions/exe-dev/
RUN curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors --max-time 30 \
      https://exe.dev/llm-gateway-models.json \
      -o /home/exedev/.pi/agent/extensions/exe-dev/catalog.json && \
    jq -e '.schemaVersion | numbers' \
      /home/exedev/.pi/agent/extensions/exe-dev/catalog.json > /dev/null

# Under pi's rpc transport the "which route" question arrives as a UI request
# nothing answers; recording the answer settles it for every unattended run.
RUN printf '%s\n' '{"version":1,"useExeIntegration":true}' \
      > /home/exedev/.pi/agent/exe-dev-llm-integration.json

# fd at the path pi checks first, so pi never tries a GitHub download on a
# fresh VM.
RUN ARCH=$(uname -m) && \
    case ${ARCH} in \
        x86_64) FD_ARCH="x86_64-unknown-linux-gnu" ;; \
        aarch64|arm64) FD_ARCH="aarch64-unknown-linux-gnu" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    FD_VERSION=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/sharkdp/fd/releases/latest | sed 's|.*/tag/||') && \
    mkdir -p /home/exedev/.pi/agent/bin && \
    TMPDIR=$(mktemp -d) && \
    curl -fsSL "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/fd-${FD_VERSION}-${FD_ARCH}.tar.gz" | \
        tar -xz -C "${TMPDIR}" && \
    mv "${TMPDIR}/fd-${FD_VERSION}-${FD_ARCH}/fd" /home/exedev/.pi/agent/bin/fd && \
    rm -rf "${TMPDIR}" && \
    chmod 0755 /home/exedev/.pi/agent/bin/fd && \
    ln -sf /home/exedev/.pi/agent/bin/fd /usr/local/bin/fd && \
    chown -R exedev:exedev /home/exedev/.pi

# herdr — the terminal-session server the control plane opens a workspace in
# and starts an agent inside. It is one static binary. The installer drops it in
# ~/.local/bin, so it is moved to a system prefix: the control plane drives it
# over a non-interactive ssh whose PATH is systemd's.
#
# `machine add` from a client is the one path that must not meet a server this
# image pre-started — it refuses a remote that already has one — so nothing here
# starts it. The control plane's first call does.
#
# The version check fails the build on a drifted installer rather than baking a
# herdr the control plane has not been read against.
ARG HERDR_VERSION=0.9.0
RUN curl -fsSL https://herdr.dev/install.sh | sh && \
    mv "$HOME/.local/bin/herdr" /usr/local/bin/herdr && \
    chmod 0755 /usr/local/bin/herdr && \
    /usr/local/bin/herdr --version | grep -qF "${HERDR_VERSION}"

# Detection manifests are fetched from herdr.dev at runtime and applied without
# a restart, so an unpinned fleet can change how it classifies an agent between
# one dispatch and the next. The control plane branches on those states, so the
# rules are frozen to what ships in the binary.
RUN mkdir -p /home/exedev/.config/herdr && \
    printf '%s\n' '[update]' 'manifest_check = false' \
        > /home/exedev/.config/herdr/config.toml && \
    chown -R exedev:exedev /home/exedev/.config/herdr

# Command Code, pinned. Installed into the user prefix so its self-updater
# works without sudo; the symlinks keep it on the default PATH for systemd.
USER exedev
RUN npm install -g command-code@1.50.0 && \
    /home/exedev/.local/bin/command-code --version && \
    rm -rf /home/exedev/.npm/_cacache

# BYOK provider config: the exe.dev LLM gateway, keyless inside exe.dev VMs.
# The default model must carry the provider prefix, or cmd resolves it against
# its own catalog and refuses it under localOnly.
COPY --chown=exedev:exedev configs/command-code/providers.json /home/exedev/.commandcode/providers.json
RUN printf '%s\n' '{"localOnly": true, "model": "exe-llm/deepseek/deepseek-v4-flash"}' > /home/exedev/.commandcode/config.json

# pb-executor spawns cmd in non-interactive shells that return at .bashrc's
# interactive guard, so the gateway key must sit above it.
RUN sed -i '1i # exe.dev LLM gateway key for cmd (non-interactive shells)\nexport COMMAND_CODE_API_KEY=exe-gateway' /home/exedev/.bashrc && \
    grep -q 'COMMAND_CODE_API_KEY' /home/exedev/.bashrc
USER root
RUN ln -sf /home/exedev/.local/bin/command-code /usr/local/bin/command-code && \
    ln -sf /home/exedev/.local/bin/command-code /usr/local/bin/cmd

# cmd-acp — the ACP bridge command-code is driven through. The whole
# directory is copied because the bridge imports routing.mjs. The version pin
# fails the build when the checkout's package.json has moved, rather than
# silently baking a different bridge.
ARG CMD_ACP_VERSION=0.2.1
COPY cmd-acp/ /opt/cmd-acp/
RUN cd /opt/cmd-acp && \
    node -e 'const v=require("/opt/cmd-acp/package.json").version; \
      if (v !== process.argv[1]) { console.error(`cmd-acp version ${v} does not match pin ${process.argv[1]}`); process.exit(1) }' "$CMD_ACP_VERSION" && \
    npm install --omit=dev --no-audit --no-fund && \
    ln -sf /opt/cmd-acp/index.mjs /usr/local/bin/cmd-acp && \
    chmod +x /usr/local/bin/cmd-acp && \
    rm -rf /root/.npm/_cacache

# Interactive Claude runs its first-run wizard — theme picker, then a login
# selector — on a machine where onboarding has never been marked complete, and
# it does so whether or not CLAUDE_CODE_OAUTH_TOKEN authenticates it. herdr
# reports those screens as `idle` because no detection rule matches them, so an
# unattended dispatch parks there looking finished. This file is what skips
# them. It carries no credential; the token lives in settings.json.
#
# Mode 600 matches what Claude writes itself: the same file later accumulates
# per-project state.
USER exedev
RUN printf '%s\n' \
      '{' \
      '  "hasCompletedOnboarding": true,' \
      '  "firstStartTime": "2026-01-01T00:00:00.000Z"' \
      '}' > /home/exedev/.claude.json && \
    chmod 600 /home/exedev/.claude.json

# A permission policy, so unattended dispatch does not stall on a tool-approval
# prompt. herdr detects that prompt correctly and refuses to type into it, which
# is the right behaviour and still a stalled attempt — the approval has to be
# unnecessary rather than answered. The VM is the sandbox.
#
# This is a fragment: the control plane merges the machine's Claude token into
# the same file with jq's recursive `*`, so both survive.
RUN mkdir -p /home/exedev/.claude && \
    printf '%s\n' \
      '{' \
      '  "permissions": {' \
      '    "defaultMode": "bypassPermissions"' \
      '  }' \
      '}' > /home/exedev/.claude/settings.json && \
    chmod 600 /home/exedev/.claude/settings.json

# pi's herdr integration grants full_lifecycle_hook_authority, so herdr stops
# reading the screen for pi entirely and trusts the hook. Claude's registers a
# SessionStart hook only and grants no such authority, so it is left off: it
# would add a hook without moving herdr off the screen manifest.
RUN /usr/local/bin/herdr integration install pi
USER root

# The operator's agent configuration, synced from repositories named at
# provision time; the image carries the mechanism and none of the content.
COPY agent-config.service /etc/systemd/system/agent-config.service
COPY agent-config-sync /usr/local/bin/agent-config-sync
COPY pb-slim /usr/local/bin/pb-slim
RUN chmod 644 /etc/systemd/system/agent-config.service && \
    chmod 755 /usr/local/bin/agent-config-sync /usr/local/bin/pb-slim && \
    systemctl enable agent-config.service

LABEL "exe.dev/variant"="dev"
LABEL "pbuntu/toolchains"="${TOOLCHAINS}"
CMD ["/usr/local/bin/init"]
