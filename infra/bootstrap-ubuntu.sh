#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this bootstrap script as root or with sudo." >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "Cannot identify this Linux distribution." >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This script supports Ubuntu only; detected ${ID:-unknown}." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg nginx certbot python3-certbot-nginx

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH="$(dpkg --print-architecture)"
CODENAME="$VERSION_CODENAME"
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
systemctl enable --now nginx

if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  usermod -aG docker "$SUDO_USER"
  echo "Added $SUDO_USER to the docker group. Log out and back in before running Docker commands without sudo."
fi

echo "Ubuntu server prerequisites installed."
echo "The docker group grants root-equivalent access to the server."
echo "Before public deployment, configure the firewall for SSH/80/443 and verify you can still access SSH."
echo "Do not expose MySQL, Redis, API, admin API or XXL-JOB container ports directly."
