# Dev variant — the per-project human development VM.
# The agent image plus the debugging and database tools a person wants when they
# SSH in. VS Code Remote SSH works over the standard sshd inherited from agent.
#
# Build:  make build-dev
# Run:    make run-dev
#
FROM ghcr.io/danruto/pbuntu:agent

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Human tools on top of the agent image (base already has neovim, less, man,
# lsof, netcat, sqlite3, btop, tree, file, strace's usual companions).
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        vim strace ltrace openssl \
        postgresql-client redis-tools && \
    rm -rf /var/lib/apt/lists/*

RUN echo 'echo -e "\e[1;36m● dev variant — project development VM\e[0m"' >> /home/exedev/.bashrc

# Paseo pins the daemon + CLI the paseo-bootstrap unit drives by bare name
# under systemd's default PATH, so the CLI goes to a system prefix — not the
# user-writable NPM_CONFIG_PREFIX the base image sets.
RUN npm install -g --prefix=/usr/local @getpaseo/cli@0.6.1 && \
    /usr/local/bin/paseo --version

# Command Code — the standalone CLI harness. Pinned to a specific version so
# image rebuilds are reproducible; bump deliberately (and verify) rather than
# tracking latest. Installed into the exedev user's writable NPM_CONFIG_PREFIX
# (like pi in the base image) so the self-updater works without sudo; a
# /usr/local/bin symlink keeps it on the default PATH for systemd/root
# contexts, the same reason paseo installs to a system prefix.
USER exedev
RUN npm install -g command-code@1.38.2 && \
    /home/exedev/.local/bin/command-code --version
USER root
RUN ln -sf /home/exedev/.local/bin/command-code /usr/local/bin/command-code && \
    ln -sf /home/exedev/.local/bin/command-code /usr/local/bin/cmd

# cmd-acp — minimal ACP (Agent Client Protocol) bridge so paseo can drive
# command-code as a provider. Installed to a system prefix: paseo's daemon
# launches it by bare name under a non-interactive environment.
COPY cmd-acp/ /opt/cmd-acp/
RUN cd /opt/cmd-acp && \
    npm install --omit=dev --no-audit --no-fund && \
    ln -sf /opt/cmd-acp/index.mjs /usr/local/bin/cmd-acp && \
    chmod +x /usr/local/bin/cmd-acp && \
    /usr/local/bin/cmd-acp --help >/dev/null 2>&1 || true

# Register command-code as a paseo ACP provider. The daemon merges this into
# its config at first boot; the paseo-bootstrap unit (provisioned at VM
# creation) owns the rest of ~/.paseo.
USER exedev
RUN mkdir -p /home/exedev/.paseo && \
    printf '%s\n' \
      '{' \
      '  "agents": {' \
      '    "providers": {' \
      '      "command-code": {' \
      '        "extends": "acp",' \
      '        "label": "Command Code",' \
      '        "command": ["/usr/local/bin/cmd-acp"]' \
      '      }' \
      '    }' \
      '  }' \
      '}' > /home/exedev/.paseo/config.json && \
    chmod 644 /home/exedev/.paseo/config.json
USER root

LABEL "exe.dev/variant"="dev"
CMD ["/usr/local/bin/init"]
