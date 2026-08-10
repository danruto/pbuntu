# Editor variant — base image + Helix editor + SSH server for herdr remote.
# Connect from phone/tablet via `herdr remote`.
#
# Build:  make build-editor
# Run:    make run-editor
#
FROM ghcr.io/danruto/pbuntu:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Install Neovim nightly (from GitHub releases — not in ubuntu apt).
# configs/nvim uses the "post-rewrite" nvim-treesitter, which calls nightly-only
# stdlib APIs (e.g. vim.list.unique) that don't exist in the apt `neovim` package
# (stable, v0.11.x). Installing to /usr/local puts it ahead of apt's nvim on PATH
# (see ENV PATH in the base Dockerfile) without needing to uninstall the apt package.
RUN NVIM_ARCH="$(uname -m)"; \
    if [ "$NVIM_ARCH" = "aarch64" ]; then NVIM_ARCH="arm64"; fi && \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-${NVIM_ARCH}.tar.gz" | \
        tar -xzC /usr/local --strip-components=1

# Install the tree-sitter CLI (from GitHub releases — not in ubuntu apt).
# nvim-treesitter shells out to `tree-sitter build` to compile parsers.
RUN TS_ARCH="$(uname -m)"; \
    if [ "$TS_ARCH" = "aarch64" ]; then TS_ARCH="arm64"; else TS_ARCH="x64"; fi && \
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-${TS_ARCH}.gz" | \
        gunzip > /usr/local/bin/tree-sitter && \
    chmod +x /usr/local/bin/tree-sitter

# Install helix (from GitHub releases — not in ubuntu apt).
# Using gj1118/helix, not upstream: configs/helix/config.toml uses that fork's
# extra editor features (rounded-corners, gradient-borders, rainbow-brackets,
# inline-blame, bufferline.render-mode), which upstream helix-editor/helix
# doesn't have and rejects as malformed config.
RUN HELIX_VERSION=$(curl -fsSL https://api.github.com/repos/gj1118/helix/releases/latest | jq -r '.tag_name') && \
    curl -fsSL "https://github.com/gj1118/helix/releases/download/${HELIX_VERSION}/helix-${HELIX_VERSION}-$(uname -m)-linux.tar.xz" | \
        tar -xJC /usr/local --strip-components=1 --wildcards '*/hx' '*/runtime' && \
    ln -sf /usr/local/hx /usr/local/bin/hx

# Enable SSH server for herdr remote access.
# The base image masks ssh.service/ssh.socket; unmask and enable them.
RUN systemctl unmask ssh.service ssh.socket && \
    systemctl enable ssh.service ssh.socket

# Add herdr config for the exedev user
USER exedev
RUN mkdir -p /home/exedev/.config/herdr

# Copy helix config
COPY --chown=exedev:exedev configs/helix/ /home/exedev/.config/helix/

# herdr remote uses SSH; ensure the user has an authorized_keys setup placeholder.
# Real keys are injected at VM creation via /exe.dev/setup or cloud-init.
RUN mkdir -p /home/exedev/.ssh && \
    chmod 700 /home/exedev/.ssh && \
    touch /home/exedev/.ssh/authorized_keys && \
    chmod 600 /home/exedev/.ssh/authorized_keys

# Pre-build fff.nvim Rust backend so users don't hit an error on first nvim launch
RUN nvim --headless "+lua require('fff.download').download_or_build_binary()" "+qa!"

# Compile treesitter parsers so users don't hit "No parser for language" errors.
# The nvim config normally expects Nix-supplied parsers (see configs/nvim/CLAUDE.md);
# here we build them with the tree-sitter CLI + gcc instead.
# NOTE: `:TSUpdate` only refreshes already-installed parsers (a no-op on a fresh
# image with none installed) and, like `:TSInstall`, returns an async task without
# blocking — quitting right after it starts would produce an empty parser dir.
# Call install() directly with the languages coding.lua attaches treesitter to
# (see the FileType autocmd there) and :wait() on the task so this RUN step
# actually installs them and blocks until it's done.
RUN nvim --headless "+lua require('nvim-treesitter.install').install({ \
  'bash', 'c', 'c_sharp', 'cpp', 'css', 'dockerfile', 'fish', \
  'gitignore', 'gleam', 'go', 'graphql', 'html', 'http', 'hurl', \
  'javascript', 'json', 'json5', 'just', 'lua', 'markdown', \
  'nix', 'python', 'regex', 'rust', 'scss', 'sql', 'svelte', 'toml', \
  'typescript', 'tsx', 'vim', 'yaml', 'zig' \
}, { summary = true }):wait(1200000)" "+qa!"

USER root

# Update MOTD to indicate this is the editor variant
RUN echo 'echo -e "\e[1;32m● editor variant — herdr remote ready\e[0m"' >> /home/exedev/.bashrc

LABEL "exe.dev/variant"="editor"
CMD ["/usr/local/bin/init"]
