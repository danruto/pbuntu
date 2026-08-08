# Minimal runner variant — Debian slim with just enough to run compiled binaries.
# No dev tooling, no LLM agents, no systemd bloat. Think: production-ish runtime.
#
# Build:  make build-runner
# Run:    make run-runner
#
FROM debian:bookworm-slim

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates curl \
        tini \
        procps lsof net-tools iproute2 \
        openssh-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/bin:/usr/bin:/bin"

# Use tini as init so signals propagate to child processes.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
