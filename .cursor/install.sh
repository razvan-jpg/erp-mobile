#!/usr/bin/env bash
# Cloud Agent install phase: prepare Docker + Supabase CLI so the local
# Supabase stack (Postgres, Auth, PostgREST, Storage, Edge Functions) can run.
# Idempotent: safe to re-run against a warm or partially prepared machine.
set -euo pipefail

SUPABASE_CLI_VERSION="2.105.0"
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> [install] Installing system packages (docker, fuse-overlayfs, iptables)"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
# docker.io + iptables are required; fuse3/fuse-overlayfs postinst can fail on
# its udev trigger inside a container, so tolerate that and verify binaries.
sudo apt-get install -y -qq docker.io iptables curl ca-certificates || true
sudo apt-get install -y -qq fuse-overlayfs || true

command -v dockerd >/dev/null || { echo "ERROR: dockerd not installed"; exit 1; }
command -v fuse-overlayfs >/dev/null || { echo "ERROR: fuse-overlayfs not installed"; exit 1; }

echo "==> [install] Configuring Docker to use the fuse-overlayfs storage driver"
# The default overlayfs/containerd snapshotter cannot convert image whiteout
# files inside this nested VM; fuse-overlayfs handles them correctly.
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "storage-driver": "fuse-overlayfs",
  "features": { "containerd-snapshotter": false }
}
JSON

echo "==> [install] Selecting the legacy iptables backend (needed for Docker bridge NAT)"
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy || true
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true

echo "==> [install] Granting the ubuntu user access to the Docker socket"
sudo groupadd -f docker
sudo usermod -aG docker ubuntu || true

echo "==> [install] Installing Supabase CLI v${SUPABASE_CLI_VERSION}"
if ! command -v supabase >/dev/null 2>&1 || [ "$(supabase --version 2>/dev/null)" != "${SUPABASE_CLI_VERSION}" ]; then
  TMP_DIR="$(mktemp -d)"
  curl -fsSL -o "${TMP_DIR}/supabase.tar.gz" \
    "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/supabase_linux_amd64.tar.gz"
  tar -xzf "${TMP_DIR}/supabase.tar.gz" -C "${TMP_DIR}"
  # The tarball ships a shim (`supabase`) plus the real `supabase-go` binary;
  # both must live on PATH together.
  sudo cp "${TMP_DIR}/supabase" /usr/local/bin/supabase
  sudo cp "${TMP_DIR}/supabase-go" /usr/local/bin/supabase-go
  sudo chmod +x /usr/local/bin/supabase /usr/local/bin/supabase-go
  rm -rf "${TMP_DIR}"
fi
supabase --version

echo "==> [install] Pre-pulling Supabase Docker images (baked into the snapshot for fast boot)"
# Start dockerd temporarily just to warm the image cache, then shut it down so
# install leaves no long-running daemon behind (start.sh owns the runtime daemon).
if ! docker info >/dev/null 2>&1; then
  sudo rm -f /var/run/docker.pid
  sudo bash -c 'nohup dockerd > /tmp/dockerd-install.log 2>&1 &'
  for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi
sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

cd "${WORKSPACE_DIR}"
export DOCKER_HOST="unix:///var/run/docker.sock"
# Bring the stack up once (pulls images + validates migrations) then tear the
# containers down, keeping the pulled images cached on disk.
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0 >/dev/null 2>&1 || true
supabase start -x vector,logflare || true
supabase stop --no-backup || true

if DPID="$(pgrep -x dockerd)"; then
  sudo kill "${DPID}" 2>/dev/null || true
fi

echo "==> [install] Done."
