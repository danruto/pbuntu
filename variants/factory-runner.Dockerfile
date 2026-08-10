# Factory runner variant — the per-project runner VM.
# Base minus the coding agents: Docker + Compose, git, gh, curl, jq, Tailscale
# and a working sshd. "Runners are not agent machines."
#
# Build:  make build-factory-runner
# Run:    make run-factory-runner
#
FROM ghcr.io/danruto/pbuntu:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Strip the coding agents and herdr. The base bakes them in for dev use; a runner
# only ever runs `docker compose`, so they are surface with no purpose here.
RUN rm -f /usr/local/bin/claude /usr/local/bin/codex /usr/local/bin/pi \
          /usr/local/bin/herdr /home/exedev/.local/bin/pi && \
    rm -rf /home/exedev/.claude /home/exedev/.codex /home/exedev/.pi

# The runner's whole job is `docker compose build/up/test`, and it has to be on
# the tailnet to be reachable. Base ships both daemons disabled.
RUN systemctl enable docker.service containerd.service tailscaled.service

# Enable SSH server — the control plane drives every runner op over SSH.
# The base image masks ssh.service/ssh.socket; unmask and enable them.
RUN systemctl unmask ssh.service ssh.socket && \
    systemctl enable ssh.service ssh.socket

USER exedev

# The control plane appends its own and the operator's key here post-boot.
RUN mkdir -p /home/exedev/.ssh && \
    chmod 700 /home/exedev/.ssh && \
    touch /home/exedev/.ssh/authorized_keys && \
    chmod 600 /home/exedev/.ssh/authorized_keys

USER root

RUN echo 'echo -e "\e[1;34m● factory-runner variant — no agents, compose only\e[0m"' >> /home/exedev/.bashrc

LABEL "exe.dev/variant"="factory-runner"
CMD ["/usr/local/bin/init"]
