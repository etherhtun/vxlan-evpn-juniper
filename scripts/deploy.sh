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

echo "Deploying lab: $LAB"
echo "Topology:      $TOPOLOGY"
echo ""
echo "This takes several minutes — vJunos-switch needs ~5-8 min per node to boot."
echo "Watch a node's boot progress in another terminal with:"
echo "  docker logs -f clab-$(grep -m1 '^name:' "$TOPOLOGY" | awk '{print $2}')-spine1"
echo ""

cd "$(dirname "$TOPOLOGY")"
containerlab deploy -t "$(basename "$TOPOLOGY")"
