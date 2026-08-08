# Minimal SSH runtime — the base for any app deployed as an exe.dev VM.
# Layer your app on top: COPY binary/dist + CMD your-server.
#
# Build:  make build-runner-ssh
# Ship:   make ship APP=myapp TAG=v1
#
FROM debian:bookworm-slim

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl \
        tini \
        procps lsof net-tools iproute2 \
        openssh-server \
        openssh-client \
    && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/sshd && \
    ssh-keygen -A

ENV PATH="/usr/local/bin:/usr/bin:/bin"

# Root is required: sshd needs it, and exe.dev VMs run as root.
# App images that want a non-root server can switch in their CMD:
#   CMD ["bash", "-c", "/usr/sbin/sshd && exec su -c 'bun run start' appuser"]
USER root  # nosemgrep: last-user-is-root (VM base image, not a container)

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]

LABEL "exe.dev/variant"="runner-ssh"
