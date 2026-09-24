#!/usr/bin/env bash
# Cloud Agent start phase: bring up the Docker daemon and the local Supabase
# stack every time the environment boots. Idempotent and safe to re-run.
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOCKER_HOST="unix:///var/run/docker.sock"

echo "==> [start] Ensuring the legacy iptables backend is selected"
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null 2>&1 || true
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >/dev/null 2>&1 || true

echo "==> [start] Starting the Docker daemon"
if ! docker info >/dev/null 2>&1; then
  sudo rm -f /var/run/docker.pid
  sudo bash -c 'nohup dockerd > /tmp/dockerd.log 2>&1 &'
  for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi
sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon did not come up"; tail -n 40 /tmp/dockerd.log 2>/dev/null; exit 1; }

echo "==> [start] Disabling bridge-nf iptables interception (fixes container->kong routing)"
# Docker enables net.bridge.bridge-nf-call-iptables=1 at daemon start, which
# routes bridged frames through iptables/conntrack. That mangles traffic to the
# published-port DNAT target (the kong gateway), so container-to-kong requests
# time out. Forcing it back to 0 keeps intra-bridge traffic on the L2 fast path.
sudo modprobe br_netfilter 2>/dev/null || true
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0 >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=0 >/dev/null 2>&1 || true

echo "==> [start] Starting the Supabase local stack"
cd "${WORKSPACE_DIR}"
# Exclude the analytics log pipeline (vector/logflare): its health check is
# flaky in this VM and it is not needed for the ERP backend.
supabase start -x vector,logflare

echo "==> [start] Supabase stack is up:"
supabase status || true
