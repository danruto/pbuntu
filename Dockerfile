# pbuntu — the one base every exe.dev VM in the fleet boots from.
#
# Deliberately thin: systemd as init, sshd, Docker, Tailscale, git and the
# handful of CLIs the control plane drives over SSH. No editors, no language
# toolchains, no coding agents — the dev variant layers those, and every other
# role (control plane, edge, runner) runs this image as is. The exe.dev disk
# quota is pooled filesystem usage across the account, so every megabyte here
# is paid once per VM.
FROM ubuntu:26.10

LABEL "exe.dev/login-user"="exedev"
LABEL "exe.dev/install-shelley"="false"

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# --no-install-recommends is what keeps docker.io from dragging in a second
# init system's worth of packages. locales-all is 240 MB for languages nothing
# on these machines reads; one generated locale is enough.
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get -y \
		-o Dpkg::Options::=--force-confold \
		-o Dpkg::Options::=--force-confdef \
		dist-upgrade && \
	echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		ca-certificates curl wget gnupg \
		git gh jq ripgrep less unzip xz-utils rsync util-linux \
		iproute2 iputils-ping \
		sudo \
		openssh-server openssh-client \
		systemd systemd-sysv dbus-user-session \
		locales \
		docker.io docker-buildx docker-compose-v2 \
		&& \
	locale-gen en_US.UTF-8 && \
	# openssh-server generates host keys during package configuration; the
	# per-image private keys must not ship.
	rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
	setcap cap_net_raw=+ep /usr/bin/ping && \
	rm -f /usr/sbin/policy-rc.d && \
	rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*

ENV LANG=en_US.UTF-8

RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tailscale && \
    rm -rf /var/lib/apt/lists/*

RUN JUST_VERSION=$(curl -fsSL https://api.github.com/repos/casey/just/releases/latest | jq -r '.tag_name') && \
    curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" | tar -xzC /usr/local/bin just && \
    chmod +x /usr/local/bin/just

# systemd inside an exe.dev VM: mask what has no hardware or console to talk
# to, and enable the daemons every role needs up before the control plane's
# first SSH — tailscaled for the join, dockerd for whatever the role runs.
RUN rm -f /etc/systemd/system/multi-user.target.wants/console-setup.service \
		/etc/systemd/system/multi-user.target.wants/unattended-upgrades.* && \
	systemctl mask -- getty.target \
		systemd-random-seed.service \
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
		ldconfig.service \
		console-getty.service \
		keyboard-setup.service \
		systemd-ask-password-console.path \
		systemd-ask-password-wall.path \
		apt-daily-upgrade.timer \
		apt-daily.timer \
		dpkg-db-backup.timer \
		e2scrub_reap.service \
		systemd-firstboot.service \
		systemd-machine-id-commit.service \
		systemd-sysctl.service && \
	systemctl disable getty.target console-getty.service getty@.service \
		systemd-logind.service systemd-ask-password-wall.service \
		systemd-ask-password-console.service && \
	systemctl enable tailscaled.service docker.service containerd.service ssh.service && \
	mkdir -p /etc/systemd/system.conf.d && \
		printf '[Manager]\nLogLevel=info\nLogTarget=console\nSystemCallArchitectures=native\nDefaultOOMPolicy=continue\n' \
			> /etc/systemd/system.conf.d/container-overrides.conf && \
	mkdir -p /etc/systemd/journald.conf.d && \
		printf '[Journal]\nStorage=persistent\nSystemMaxUse=200M\n' \
			> /etc/systemd/journald.conf.d/persistent.conf && \
	systemctl set-default multi-user.target

# The ubuntu user (UID 1000) becomes exedev, the login user exe.dev expects.
RUN usermod -l exedev -c "exe.dev user" ubuntu && \
	groupmod -n exedev ubuntu && \
	mv /home/ubuntu /home/exedev && \
	usermod -d /home/exedev exedev && \
	usermod -aG sudo,docker exedev && \
	sed -i 's/^ubuntu:/exedev:/' /etc/subuid /etc/subgid && \
	echo 'exedev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
	echo 'Defaults:exedev verifypw=any' >> /etc/sudoers && \
	chown -R exedev:exedev /home/exedev && \
	# Linger so /run/user/1000 exists for user services without a login session.
	mkdir -p /var/lib/systemd/linger && \
	touch /var/lib/systemd/linger/exedev && \
	mkdir -p /home/exedev/.ssh && chmod 700 /home/exedev/.ssh && \
	touch /home/exedev/.ssh/authorized_keys && chmod 600 /home/exedev/.ssh/authorized_keys && \
	chown -R exedev:exedev /home/exedev/.ssh && \
	touch /home/exedev/.hushlogin && chown exedev:exedev /home/exedev/.hushlogin && \
	rm -rf /etc/update-motd.d/* /etc/motd

# systemd-growfs@-.service resizes the root filesystem on first boot after
# exe.dev grows the disk to the size the VM was created with.
RUN echo '/dev/vda / ext4 defaults,x-systemd.growfs 0 1' > /etc/fstab

# Stop systemd wiping /tmp at boot; that races non-systemd users of the system
# that also run at boot.
COPY tmpfiles-tmp.conf /etc/tmpfiles.d/tmp.conf

ENV EXEUNTU=1
ENV PATH="/usr/local/bin:${PATH}"

USER exedev
WORKDIR /home/exedev
# XDG_RUNTIME_DIR is not populated for SSH sessions despite libpam-systemd.
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/exedev/.bashrc && \
    echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> /home/exedev/.bashrc && \
    echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> /home/exedev/.profile && \
    git config --global init.defaultBranch main
USER root

# /exe.dev/setup runs once, on first boot, as exedev.
COPY exe-setup.service /etc/systemd/system/exe-setup.service
RUN chmod 644 /etc/systemd/system/exe-setup.service && \
    systemctl enable exe-setup.service

# Named init so exe.dev's exetini exec's it as PID 1 rather than forking it.
COPY init-wrapper.sh /usr/local/bin/init

CMD ["/usr/local/bin/init"]
