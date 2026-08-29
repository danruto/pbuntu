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

LABEL "exe.dev/variant"="dev"
CMD ["/usr/local/bin/init"]
