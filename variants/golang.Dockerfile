# Golang dev variant — layers Go toolchain on top of the base exeuntu image.
#
# Build:  make build-golang
# Run:    make run-golang
#
FROM ghcr.io/danruto/pbuntu:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Install latest stable Go from go.dev (fresher than apt)
RUN ARCH=$(dpkg --print-architecture) && \
    GO_VERSION=$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[0].version') && \
    curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -xzC /usr/local && \
    ln -sf /usr/local/go/bin/go /usr/local/bin/go && \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

USER exedev
RUN mkdir -p /home/exedev/go/bin && \
    echo 'export PATH="$HOME/go/bin:$PATH"' >> /home/exedev/.bashrc
USER root

LABEL "exe.dev/variant"="golang"
CMD ["/usr/local/bin/init"]
