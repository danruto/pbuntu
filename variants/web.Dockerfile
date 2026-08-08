# Bun web variant — Bun runtime for frontend / fullstack JS/TS development.
#
# Build:  make build-web
# Run:    make run-web
#
FROM ghcr.io/danruto/pbuntu:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN curl -fsSL https://bun.sh/install | bash && \
    ln -sf /root/.bun/bin/bun /usr/local/bin/bun

# Enable shelley (off by default in base, opt-in for web variant)
RUN systemctl enable shelley.socket

LABEL "exe.dev/variant"="web"
CMD ["/usr/local/bin/init"]
