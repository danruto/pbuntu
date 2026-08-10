# Bun web variant — Bun runtime for frontend / fullstack JS/TS development.
#
# Build:  make build-web
# Run:    make run-web
#
FROM ghcr.io/danruto/pbuntu:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# BUN_INSTALL puts bun in /usr/local/bin directly; installing to /root/.bun and
# symlinking leaves it unreachable for exedev, since /root is mode 0700.
RUN curl -fsSL https://bun.sh/install | env BUN_INSTALL=/usr/local bash && \
    bun --version

# Enable shelley (off by default in base, opt-in for web variant)
RUN systemctl enable shelley.socket

LABEL "exe.dev/variant"="web"
CMD ["/usr/local/bin/init"]
