#!/bin/bash
# Usage: ./scripts/deploy.sh <lab-folder>
# Example: ./scripts/deploy.sh 01-ospf-ibgp
#
# Deploys the named lab's containerlab topology (bare fabric — no per-node
# config yet). Follow the lab's steps/ by hand, or run switch.sh to push the
# full working config.

set -euo pipefail

LAB="${1:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$LAB" ]; then
  echo "Usage: $0 <lab-folder>"
  echo ""
  echo "Available labs:"
  ls "$REPO_ROOT/labs/" 2>/dev/null | sed 's/^/  /'
  exit 1
fi

TOPOLOGY="${REPO_ROOT}/labs/${LAB}/topology.clab.yml"
if [ ! -f "$TOPOLOGY" ]; then
  echo "Topology not found: $TOPOLOGY"
  echo ""
  echo "Available labs:"
  ls "$REPO_ROOT/labs/" 2>/dev/null | sed 's/^/  /'
  exit 1
fi

PREFIX="$(grep -m1 '^name:' "$TOPOLOGY" | awk '{print $2}')"

# ── Pre-flight: refuse to run if ANOTHER fabric is already up ──
# A 2x2 vJunos fabric needs ~16 GB RAM; two at once starve the host and boot
# 'unhealthy'. Only one lab may run at a time.
OTHER="$(docker ps --format '{{.Names}}' 2>/dev/null | grep '^clab-' | grep -v "^clab-${PREFIX}-" || true)"
if [ -n "$OTHER" ]; then
  echo "ERROR: another fabric is already running — wipe it before deploying '$LAB'."
  echo ""
  echo "Running now:"
  echo "$OTHER" | sed 's/^/  /'
  echo ""
  echo "Only ONE 2x2 vJunos fabric fits on this host. Clear it with:"
  echo "  sudo docker rm -f \$(docker ps -aq --filter name=clab-)   # force-remove ALL clab containers"
  echo "  # (or, if containerlab still tracks it: sudo containerlab destroy --all)"
  echo ""
  echo "Then re-run: ./scripts/deploy.sh $LAB"
  exit 1
fi

# If THIS lab's containers already exist, that's a redeploy — reconfigure cleanly.
RECONF=""
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^clab-${PREFIX}-"; then
  echo "Note: '$LAB' containers already exist — redeploying with --reconfigure."
  RECONF="--reconfigure"
fi

echo "Deploying lab: $LAB"
echo "Topology:      $TOPOLOGY"
echo ""
echo "This takes several minutes — vJunos-switch needs ~5-8 min per node to boot."
echo "Watch a node's boot progress in another terminal with:"
echo "  docker logs -f clab-${PREFIX}-spine1"
echo ""

cd "$(dirname "$TOPOLOGY")"
containerlab deploy -t "$(basename "$TOPOLOGY")" ${RECONF}
