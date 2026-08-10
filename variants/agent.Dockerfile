# Agent variant — kitchen-sink image for factory coding-agent VMs.
# Base + Go/Rust/Node/Python toolchains + the agent tool set + herdr integrations
# + sshd + a herdr-server user unit, so an agent VM boots ready to clone and work.
#
# Build:  make build-agent
# Run:    make run-agent
#
FROM ghcr.io/danruto/pbuntu:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Tool delta over base (base already has git, gh, jq, rg, just, curl, wget, btop,
# sqlite3, neovim, docker, tailscale, herdr, claude, codex, pi).
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        fzf git-delta tmux zsh direnv xz-utils && \
    rm -rf /var/lib/apt/lists/*

# fd is already in the image at pi's bundled path; expose it on PATH instead of
# installing a second copy.
RUN ln -sf /home/exedev/.pi/agent/bin/fd /usr/local/bin/fd

# Go — latest stable from go.dev (fresher than apt)
RUN ARCH=$(dpkg --print-architecture) && \
    GO_VERSION=$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[0].version') && \
    curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -xzC /usr/local && \
    ln -sf /usr/local/go/bin/go /usr/local/bin/go && \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt && \
    go version

# Node.js LTS + corepack + pnpm.
# Extracted into /usr/local so bin/node, bin/npm, bin/corepack land on PATH.
# COREPACK_ENABLE_DOWNLOAD_PROMPT=0 stops corepack blocking on a y/N prompt when
# a repo pins a package manager — an agent has no tty to answer it.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN ARCH=$(dpkg --print-architecture) && \
    case "${ARCH}" in \
        amd64) NODE_ARCH=x64 ;; \
        arm64) NODE_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version') && \
    curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" | \
        tar -xJC /usr/local --strip-components=1 \
            --exclude='*/README.md' --exclude='*/LICENSE' --exclude='*/CHANGELOG.md' && \
    corepack enable && \
    node --version && npm --version

# Python — uv (also provides uvx)
RUN curl -LsSf https://astral.sh/uv/install.sh | \
        env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh && \
    uv --version && uvx --version

# Bun — installed system-wide (BUN_INSTALL), not into /root, so exedev can run it
RUN curl -fsSL https://bun.sh/install | env BUN_INSTALL=/usr/local bash && \
    bun --version

# Enable tailscaled and dockerd — base disables both. `tailscale up` needs the
# daemon already running (D-018/D-026), and the default project test command an
# agent runs is `docker compose run --rm test` (D-029).
RUN systemctl enable tailscaled.service docker.service containerd.service

# Enable SSH server — the control plane drives herdr over SSH (D-013/D-016).
# The base image masks ssh.service/ssh.socket; unmask and enable them.
RUN systemctl unmask ssh.service ssh.socket && \
    systemctl enable ssh.service ssh.socket

# herdr-server as a systemd user unit. `systemctl --user enable` needs a running
# user bus, so link the wants symlink by hand at build time; linger is on in base.
COPY herdr-server.service /home/exedev/.config/systemd/user/herdr-server.service
RUN mkdir -p /home/exedev/.config/systemd/user/default.target.wants && \
    ln -sf ../herdr-server.service \
        /home/exedev/.config/systemd/user/default.target.wants/herdr-server.service && \
    chown -R exedev:exedev /home/exedev/.config/systemd

USER exedev

# Rust via rustup (minimal profile + the two components we actually use)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
        --profile minimal \
        --default-toolchain stable \
        -c rustfmt -c clippy && \
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /home/exedev/.bashrc

# cargo-nextest + cargo-watch from prebuilt binaries (cargo install would compile
# them from source on every image build)
RUN . /home/exedev/.cargo/env && \
    case "$(uname -m)" in \
        x86_64) NEXTEST_URL=https://get.nexte.st/latest/linux ;; \
        aarch64|arm64) NEXTEST_URL=https://get.nexte.st/latest/linux-arm ;; \
        *) echo "Unsupported architecture: $(uname -m)" && exit 1 ;; \
    esac && \
    curl -fsSL "${NEXTEST_URL}" | tar -xzC /home/exedev/.cargo/bin && \
    WATCH_VERSION=$(curl -fsSL https://api.github.com/repos/watchexec/cargo-watch/releases/latest | jq -r '.tag_name') && \
    curl -fsSL "https://github.com/watchexec/cargo-watch/releases/download/${WATCH_VERSION}/cargo-watch-${WATCH_VERSION}-$(uname -m)-unknown-linux-gnu.tar.xz" | \
        tar -xJC /home/exedev/.cargo/bin --wildcards --strip-components=1 '*/cargo-watch' && \
    cargo nextest --version && cargo watch --version

# Node package manager for the exedev user: pre-seed the corepack cache so the
# first `pnpm` in an agent pane doesn't have to download it.
RUN corepack prepare pnpm@latest --activate && \
    pnpm --version

RUN echo 'export PATH="$HOME/go/bin:$PATH"' >> /home/exedev/.bashrc && \
    mkdir -p /home/exedev/go/bin

# Herdr integrations for the three agent kinds (G5 — this build is the proof).
# pi is the lifecycle-authority integration; claude and codex are session-identity
# only and need ~/.claude and ~/.codex to pre-exist, which the base image creates.
RUN mkdir -p /home/exedev/.config/herdr && \
    herdr integration install pi && \
    herdr integration install claude && \
    herdr integration install codex && \
    herdr integration status

# The control plane appends its own and the operator's key here post-boot (D-018).
RUN mkdir -p /home/exedev/.ssh && \
    chmod 700 /home/exedev/.ssh && \
    touch /home/exedev/.ssh/authorized_keys && \
    chmod 600 /home/exedev/.ssh/authorized_keys

USER root

RUN echo 'echo -e "\e[1;35m● agent variant — factory agent VM\e[0m"' >> /home/exedev/.bashrc

LABEL "exe.dev/variant"="agent"
CMD ["/usr/local/bin/init"]
