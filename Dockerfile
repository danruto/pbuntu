# Build the guest-facing pbuntu helper (forked from exeuntu).
FROM docker.io/library/golang:1.26.7 AS exeuntu-cli
ARG EXEUNTU_GIT_VERSION=unknown
WORKDIR /src/exeuntu-cli
COPY cli/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -mod=mod -tags osusergo,netgo \
        -ldflags "-X main.gitVersion=${EXEUNTU_GIT_VERSION} -extldflags=-static -s -w" \
        -o /out/exeuntu .

FROM ubuntu:26.10

# pbuntu — personal fork of exeuntu (ghcr.io/danruto/pbuntu)
LABEL "exe.dev/login-user"="exedev"
LABEL "exe.dev/install-shelley"="true"

# Switch from dash to bash by default.
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Remove minimization restrictions and install packages with documentation
# We aim for a usable non-minimal system.
# 26.10 base image is not minimized (unlike 24.04) — docs/man pages already present.
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirror://mirrors.ubuntu.com/mirrors.txt|' /etc/apt/sources.list && \
        rm -f /etc/dpkg/dpkg.cfg.d/excludes /etc/dpkg/dpkg.cfg.d/01_nodoc && \
	apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get -y \
		-o Dpkg::Options::=--force-confold \
		-o Dpkg::Options::=--force-confdef \
		dist-upgrade && \
	# Pre-configure debconf to avoid interactive prompts
	echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
	# Pre-configure pbuilder to avoid mirror prompt
	echo 'pbuilder pbuilder/mirrorsite string http://archive.ubuntu.com/ubuntu' | debconf-set-selections && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		ca-certificates wget ripgrep \
		locales locales-all \
		git jq sqlite3 curl neovim lsof iproute2 less nginx \
		make tree net-tools file build-essential \
		psmisc bsdmainutils sudo socat \
		openssh-server openssh-client \
		libcap2-bin unzip util-linux rsync \
		iputils-ping socat netcat-openbsd \
		ubuntu-server ubuntu-dev-tools ubuntu-standard \
		man-db manpages manpages-dev \
		mitmproxy \
		systemd systemd-sysv \
		btop \
		fontconfig fonts-noto-color-emoji \
		docker.io docker-buildx docker-compose-v2 \
		bubblewrap \
		gh \
		dbus-user-session \
		&& apt-get remove -y pollinate ubuntu-fan || true && \
		# openssh-server generates host keys during package configuration.
		# Do not bake those per-image private keys into exeuntu.
		rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
		# Allow non-root users to use ping without sudo by granting CAP_NET_RAW
		setcap cap_net_raw=+ep /usr/bin/ping && \
	fc-cache -f -v && \
	# Remove policy-rc.d so services can start normally (the base image includes this
	# to prevent services from starting during build, but we run systemd at runtime)
	rm -f /usr/sbin/policy-rc.d

# Install Tailscale (keyring method, per https://tailscale.com/install.sh)
# This must run after ca-certificates and curl are installed.
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale

COPY --from=exeuntu-cli /out/exeuntu /usr/local/bin/exeuntu

# Install standalone CLI tools from GitHub releases (no build deps)
ARG TARGETARCH

# just (command runner)
RUN JUST_VERSION=$(curl -fsSL https://api.github.com/repos/casey/just/releases/latest | jq -r '.tag_name') && \
    curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" | tar -xzC /usr/local/bin just && \
    chmod +x /usr/local/bin/just

# gitui (git TUI)
RUN GITUI_VERSION=$(curl -fsSL https://api.github.com/repos/extrawurst/gitui/releases/latest | jq -r '.tag_name') && \
    curl -fsSL "https://github.com/extrawurst/gitui/releases/download/${GITUI_VERSION}/gitui-linux-$(uname -m).tar.gz" | tar -xzC /usr/local/bin && \
    chmod +x /usr/local/bin/gitui

# cull (disk space TUI)
RUN CULL_VERSION=$(curl -fsSL https://api.github.com/repos/legostin/cull/releases/latest | jq -r '.tag_name') && \
    curl -fsSL "https://github.com/legostin/cull/releases/download/${CULL_VERSION}/cull_linux_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tar.gz" | tar -xzC /usr/local/bin cull && \
    chmod +x /usr/local/bin/cull

# elio (file manager)
RUN ELIO_VERSION=$(curl -fsSL https://api.github.com/repos/elio-fm/elio/releases/latest | jq -r '.tag_name') && \
    ELIO_NO_V="${ELIO_VERSION#v}" && \
    curl -fsSL "https://github.com/elio-fm/elio/releases/download/${ELIO_VERSION}/elio-${ELIO_NO_V}-$(uname -m)-unknown-linux-gnu.tar.gz" | tar -xzC /usr/local/bin --wildcards --strip-components=1 '*/elio' && \
    chmod +x /usr/local/bin/elio

# Install Node.js for bb host-daemon enrollment and the project toolchain.
# Keep npm's global prefix user-writable: the bb machine installer runs as exedev.
RUN ARCH="$(uname -m)" && \
    case "${ARCH}" in x86_64) NODE_ARCH=x64 ;; aarch64|arm64) NODE_ARCH=arm64 ;; *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; esac && \
    NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.version | startswith("v24."))][0].version') && \
    curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" | \
        tar -xJC /usr/local --strip-components=1 --exclude='*/README.md' --exclude='*/LICENSE' --exclude='*/CHANGELOG.md' && \
    node --version && npm --version
ENV NPM_CONFIG_PREFIX="/home/exedev/.local"

# Configure systemd
RUN rm /etc/systemd/system/multi-user.target.wants/console-setup.service \
		/etc/systemd/system/multi-user.target.wants/ModemManager.service \
		/etc/systemd/system/multi-user.target.wants/snapd.* \
		/etc/systemd/system/multi-user.target.wants/unattended-upgrades.* \
		/etc/systemd/system/multi-user.target.wants/ubuntu-advantage.service && \
	systemctl mask -- getty.target \
		fwupd.service \
		fwupd-refresh.service \
		fwupd-refresh.timer \
		systemd-random-seed.service \
		iscsid.socket \
		dm-event.socket \
		man-db.timer \
		update-notifier-download.timer \
		update-notifier-motd.timer \
		atop-rotate.timer \
		dpkg-db-backup.timer \
		e2scrub_all.timer \
		etc-resolv.conf.mount \
		etc-hosts.mount \
		etc-hostname.mount \
		-.mount \
		systemd-resolved.service \
		systemd-remount-fs.service \
		systemd-sysusers.service \
		systemd-update-done.service \
		systemd-update-utmp.service \
		systemd-journal-catalog-update.service \
		modprobe@.service \
		systemd-modules-load.service \
		systemd-udevd.service \
		systemd-udevd-control.service \
		systemd-udevd-kernel.service \
		systemd-udev-trigger.service \
		systemd-udev-settle.service \
		systemd-hwdb-update.service \
		ubuntu-fan.service \
		ldconfig.service \
		unattended-upgrades.service \
		lxd-installer.socket \
	        console-getty.service \
		keyboard-setup.service \
		systemd-ask-password-console.path \
		systemd-ask-password-wall.path \
		ssh.socket \
		ssh.service \
		plymouth.service \
		plymouth-start.service \
		plymouth-quit.service \
		plymouth-quit-wait.service \
		plymouth-read-write.service \
		plymouth-switch-root.service \
		plymouth-switch-root-initramfs.service \
		plymouth-halt.service \
		plymouth-reboot.service \
		plymouth-poweroff.service \
		plymouth-kexec.service \
		apt-daily-upgrade.timer \
		apt-daily.timer \
		plymouth-log.service \
		atop-rotate.timer \
		atop.service \
		atopacct.service && \
	# systemd-logind is disabled but not masked. It's involved in populating the XDG runtime dir sockets... somehow
	systemctl disable docker.service containerd.service getty.target systemd-logind.service \
		nginx.service \
                   console-getty.service \
                   getty@.service \
                   snapd.socket \
		   motd-news.timer motd-news.service \
		    apport.service apport-autoreport.timer apport-autoreport.path apport-forward.socket \
		    snapd.snap-repair.timer snapd.snap-repair.service \
		    udisks2.service \
		   ufw.service \
		   lvm2-lvmpolld.socket \
                   systemd-ask-password-wall.service \
                   systemd-ask-password-console.service \
                   systemd-machine-id-commit.service \
                   systemd-modules-load.service \
                   systemd-sysctl.service \
                   systemd-firstboot.service \
                   systemd-udevd.service \
                   systemd-udev-trigger.service \
                   systemd-udev-settle.service \
		   e2scrub_reap.service \
		   systemd-update-utmp.service \
		   systemd-hwdb-update.service \
		   multipathd.service && \
	systemctl enable tailscaled.service && \
	mkdir -p /etc/systemd/system.conf.d && \
    		echo '[Manager]' > /etc/systemd/system.conf.d/container-overrides.conf && \
    		echo 'LogLevel=info' >> /etc/systemd/system.conf.d/container-overrides.conf && \
    		echo 'LogTarget=console' >> /etc/systemd/system.conf.d/container-overrides.conf && \
    		echo 'SystemCallArchitectures=native' >> /etc/systemd/system.conf.d/container-overrides.conf && \
    		echo 'DefaultOOMPolicy=continue' >> /etc/systemd/system.conf.d/container-overrides.conf && \
	mkdir -p /etc/systemd/journald.conf.d && \
		echo '[Journal]' > /etc/systemd/journald.conf.d/persistent.conf && \
		echo 'Storage=persistent' >> /etc/systemd/journald.conf.d/persistent.conf && \
	systemctl set-default multi-user.target

# Modify existing ubuntu user (UID 1000) to become exedev user
RUN usermod -l exedev -c "exe.dev user" ubuntu && \
	groupmod -n exedev ubuntu && \
	mv /home/ubuntu /home/exedev && \
	usermod -d /home/exedev exedev && \
	usermod -aG sudo exedev && \
	usermod -aG docker exedev && \
	sed -i 's/^ubuntu:/exedev:/' /etc/subuid /etc/subgid && \
	echo 'exedev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
	echo 'Defaults:exedev verifypw=any' >> /etc/sudoers && \
	# overlayfs copy-up may change ownership; fix it
	chown -R exedev:exedev /home/exedev && \
	# Manually enable linger, this should autopopulate /run/user/1000
	mkdir -p /var/lib/systemd/linger && \
	touch /var/lib/systemd/linger/exedev

# Bake /etc/fstab so systemd-growfs@-.service resizes the root filesystem on
# first boot after the disk is grown.
RUN echo '/dev/vda / ext4 defaults,x-systemd.growfs 0 1' > /etc/fstab

# Stop systemd wiping /tmp at boot; that races non-systemd users of the system
# that also run at boot.
COPY tmpfiles-tmp.conf /etc/tmpfiles.d/tmp.conf

ENV EXEUNTU=1

# https://github.com/trfore/docker-ubuntu2404-systemd/blob/main/Dockerfile suggests the following
# might be useful?
# STOPSIGNAL SIGRTMIN+3


ENV PATH="/usr/local/bin:${PATH}"

RUN mkdir -p /home/exedev /home/exedev/.config/shelley /home/exedev/.config/nvim && \
    chown exedev:exedev /home/exedev /home/exedev/.config /home/exedev/.config/shelley /home/exedev/.config/nvim

# Copy neovim config (lazy.nvim auto-bootstraps plugins on first run)
COPY --chown=exedev:exedev configs/nvim/ /home/exedev/.config/nvim/

USER exedev

WORKDIR /home/exedev

# Update PATH in .bashrc to include .local/bin and set XDG_RUNTIME_DIR for systemd user services
# XDG paths are not autopopulated despite the presense of libpam-systemd. Manually add them here.
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/exedev/.bashrc && \
    echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> /home/exedev/.bashrc && \
    echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> /home/exedev/.profile

# Configure git to use 'main' as default branch name
RUN git config --global init.defaultBranch main

# Switch back to root to install systemd service
USER root

# Disable Ubuntu's default MOTD (the sudo hint, etc.)
RUN rm -rf /etc/update-motd.d/* /etc/motd && touch /home/exedev/.hushlogin && chown exedev:exedev /home/exedev/.hushlogin

# Add custom MOTD to exedev's .bashrc (ignores .hushlogin - we handle that ourselves)
COPY motd-snippet.bash /tmp/motd-snippet.bash
RUN cat /tmp/motd-snippet.bash >> /home/exedev/.bashrc && rm /tmp/motd-snippet.bash

# Create systemd service for optional BB machine enrollment. The provisioning
# layer writes /exe.dev/bb.env with join credentials at first boot; credentials
# are never baked into the image.
COPY bb-enroll.service /etc/systemd/system/bb-enroll.service
COPY bb-enroll /usr/local/bin/bb-enroll
RUN chmod 644 /etc/systemd/system/bb-enroll.service && \
    chmod 755 /usr/local/bin/bb-enroll && \
    systemctl enable bb-enroll.service

# Create systemd service for optional agent-configuration sync. The provisioning
# layer writes /exe.dev/agent-config.env naming the repositories to pull; neither
# a repository nor any content of one is baked into the image.
COPY agent-config.service /etc/systemd/system/agent-config.service
COPY agent-config-sync /usr/local/bin/agent-config-sync
RUN chmod 644 /etc/systemd/system/agent-config.service && \
    chmod 755 /usr/local/bin/agent-config-sync && \
    systemctl enable agent-config.service

# Create systemd socket and service for Shelley (socket activation).
# The shelley binary itself is installed at vm creation.
COPY shelley.socket /etc/systemd/system/shelley.socket
COPY shelley.service /etc/systemd/system/shelley.service
RUN chmod 644 /etc/systemd/system/shelley.socket /etc/systemd/system/shelley.service && \
    systemctl enable shelley.socket

# Create systemd oneshot service for /exe.dev/setup script
COPY exe-setup.service /etc/systemd/system/exe-setup.service
RUN chmod 644 /etc/systemd/system/exe-setup.service && \
    systemctl enable exe-setup.service

# TODO(crawshaw/philip): This is called init so that exetini decides
# this wrapper script is an init, and exec's it rather than forking it.
# It would be better if you could indicate that via an env variable or something.
COPY init-wrapper.sh /usr/local/bin/init

# Create config directories for LLM agents
RUN mkdir -p /home/exedev/.claude /home/exedev/.codex /home/exedev/.pi && \
    chown -R exedev:exedev /home/exedev/.claude /home/exedev/.codex /home/exedev/.pi

# Copy the image's own agent instructions and point every harness at them.
#
# They live outside $HOME and outside any single agent's config directory.
# agent-config-sync merges them with the operator's into
# ~/.config/agents/AGENTS.md and repoints these symlinks there. A source file
# inside that user-writable tree would be truncated by its own merge, and one
# inside a single agent's directory outlives that agent's presence: shelley is
# enabled only in the web variant, so on every other variant the canonical file
# would sit in the config directory of an agent that never runs.
COPY AGENTS.md /etc/agents/AGENTS.md
RUN chmod 644 /etc/agents/AGENTS.md && \
    ln -s /etc/agents/AGENTS.md /home/exedev/.claude/CLAUDE.md && \
    ln -s /etc/agents/AGENTS.md /home/exedev/.codex/AGENTS.md && \
    ln -s /etc/agents/AGENTS.md /home/exedev/.pi/AGENTS.md && \
    ln -s /etc/agents/AGENTS.md /home/exedev/.config/shelley/AGENTS.md

# Install Claude and Codex through exeuntu's direct updaters.
USER root
RUN exeuntu update claude && \
    test -x /usr/local/bin/claude && \
    /usr/local/bin/claude --version
RUN exeuntu update codex && \
    test -x /usr/local/bin/codex && \
    /usr/local/bin/codex --version

# Install pi (pi-coding-agent) from npm. It must land in the user-writable
# NPM_CONFIG_PREFIX (not a system prefix like paseo's): pi's self-updater
# (`pi update --self`) needs to write where it is installed.
ARG PI_VERSION=
USER exedev
RUN if [ -n "${PI_VERSION}" ]; then \
        npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}"; \
    else \
        npm install -g --ignore-scripts @earendil-works/pi-coding-agent; \
    fi && \
    test -x /home/exedev/.local/bin/pi && \
    /home/exedev/.local/bin/pi --version
USER root
RUN ln -sf /home/exedev/.local/bin/pi /usr/local/bin/pi

# Default pi packages, preinstalled into ~/.pi/agent. Left unpinned so
# `pi update --extensions` moves them forward inside running VMs.
USER exedev
RUN pi install npm:pi-ponytail && \
    pi install npm:cc-safety-net && \
    pi install npm:pi-web-access && \
    pi install npm:pi-hermes-memory && \
    pi list | grep -q pi-ponytail && \
    pi list | grep -q cc-safety-net && \
    pi list | grep -q pi-web-access && \
    pi list | grep -q pi-hermes-memory

# Point pi-hermes-memory's background reviews (correction saves, session
# flushes, consolidation) at the exe.dev gateway's cheap DeepSeek Flash route
# instead of the user's default chat model.
RUN printf '%s\n' '{"llmModelOverride":"exe-dev-fireworks/accounts/fireworks/models/deepseek-v4-flash-0731@llm","llmThinkingOverride":"off"}' \
      > /home/exedev/.pi/agent/hermes-memory-config.json && \
    jq -e .llmModelOverride /home/exedev/.pi/agent/hermes-memory-config.json > /dev/null && \
    chown exedev:exedev /home/exedev/.pi/agent/hermes-memory-config.json
USER root

# Install the pi exe.dev extension (LLM integration + environment context).
# The bundled public catalog supplies pricing and compatibility metadata only;
# reflection-discovered integrations supply every model and provider route.
COPY pi-extension/ /home/exedev/.pi/agent/extensions/exe-dev/
RUN curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors --max-time 30 \
      https://exe.dev/llm-gateway-models.json \
      -o /home/exedev/.pi/agent/extensions/exe-dev/catalog.json && \
    jq -e '.schemaVersion | numbers' \
      /home/exedev/.pi/agent/extensions/exe-dev/catalog.json > /dev/null

# The extension asks which model route to take when this file is absent, and
# under pi's rpc transport that question arrives as an extension_ui_request
# nothing is there to answer — the agent exits before its first turn. Recording
# the answer here settles it for every unattended machine; a deployment that
# ships a curated provider list overwrites it at provision time.
RUN printf '%s\n' '{"version":1,"useExeIntegration":true}' \
      > /home/exedev/.pi/agent/exe-dev-llm-integration.json
RUN chown -R exedev:exedev /home/exedev/.pi/agent

# Pre-install fd at the path pi checks first (~/.pi/agent/bin/fd), so pi
# doesn't try (and on a fresh VM, often fail with a GitHub API 403) to
# download it on first use.
RUN ARCH=$(uname -m) && \
    case ${ARCH} in \
        x86_64) FD_ARCH="x86_64-unknown-linux-gnu" ;; \
        aarch64|arm64) FD_ARCH="aarch64-unknown-linux-gnu" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    FD_VERSION=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/sharkdp/fd/releases/latest | sed 's|.*/tag/||') && \
    mkdir -p /home/exedev/.pi/agent/bin && \
    TMPDIR=$(mktemp -d) && \
    curl -fsSL "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/fd-${FD_VERSION}-${FD_ARCH}.tar.gz" | \
        tar -xz -C "${TMPDIR}" && \
    mv "${TMPDIR}/fd-${FD_VERSION}-${FD_ARCH}/fd" /home/exedev/.pi/agent/bin/fd && \
    rm -rf "${TMPDIR}" && \
    chmod 0755 /home/exedev/.pi/agent/bin/fd && \
    chown -R exedev:exedev /home/exedev/.pi/agent/bin

# Custom nginx config and index page (nginx is installed but disabled by default)
COPY nginx.conf /etc/nginx/sites-available/default
COPY index.html /var/www/html/index.html
RUN chmod 644 /var/www/html/index.html

# Install xterm-ghostty terminfo for Ghostty terminal support
COPY xterm-ghostty.terminfo /tmp/xterm-ghostty.terminfo
RUN tic -x - < /tmp/xterm-ghostty.terminfo && rm /tmp/xterm-ghostty.terminfo

# Expose the web server ports
EXPOSE 8000 9999

CMD ["/usr/local/bin/init"]
