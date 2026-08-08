# Rust + Bun dev variant — Rust toolchain and Bun runtime for Tauri / WASM work.
#
# Build:  make build-rust
# Run:    make run-rust
#
FROM ghcr.io/danruto/pbuntu:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Bun (JavaScript runtime + bundler, needed for Tauri frontend)
RUN curl -fsSL https://bun.sh/install | bash && \
    ln -sf /root/.bun/bin/bun /usr/local/bin/bun

# Rust via rustup (non-interactive, minimal profile — no docs, no extra targets)
USER exedev
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --profile minimal \
    --default-toolchain stable && \
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /home/exedev/.bashrc

# Pre-seed the cargo registry so first cargo build doesn't spend minutes indexing.
# We only fetch the index; crate sources are fetched on-demand.
RUN . /home/exedev/.cargo/env && \
    rustup default stable && \
    cargo search ripgrep > /dev/null 2>&1 || true

USER root

LABEL "exe.dev/variant"="rust"
CMD ["/usr/local/bin/init"]
