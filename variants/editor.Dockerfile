# Editor variant — base image + Helix editor + SSH server for herdr remote.
# Connect from phone/tablet via `herdr remote`.
#
# Build:  make build-editor
# Run:    make run-editor
#
FROM ghcr.io/danruto/pbuntu:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Install helix (from GitHub releases — not in ubuntu apt)
RUN HELIX_VERSION=$(curl -fsSL https://api.github.com/repos/helix-editor/helix/releases/latest | jq -r '.tag_name') && \
    curl -fsSL "https://github.com/helix-editor/helix/releases/download/${HELIX_VERSION}/helix-${HELIX_VERSION}-$(uname -m)-linux.tar.xz" | \
        tar -xJC /usr/local --strip-components=1 --wildcards '*/hx' '*/runtime' && \
    ln -sf /usr/local/hx /usr/local/bin/hx

# Enable SSH server for herdr remote access.
# The base image masks ssh.service/ssh.socket; unmask and enable them.
RUN systemctl unmask ssh.service ssh.socket && \
    systemctl enable ssh.service ssh.socket

# Add herdr config for the exedev user
USER exedev
RUN mkdir -p /home/exedev/.config/herdr

# herdr remote uses SSH; ensure the user has an authorized_keys setup placeholder.
# Real keys are injected at VM creation via /exe.dev/setup or cloud-init.
RUN mkdir -p /home/exedev/.ssh && \
    chmod 700 /home/exedev/.ssh && \
    touch /home/exedev/.ssh/authorized_keys && \
    chmod 600 /home/exedev/.ssh/authorized_keys

USER root

# Update MOTD to indicate this is the editor variant
RUN echo 'echo -e "\e[1;32m● editor variant — herdr remote ready\e[0m"' >> /home/exedev/.bashrc

LABEL "exe.dev/variant"="editor"
CMD ["/usr/local/bin/init"]
