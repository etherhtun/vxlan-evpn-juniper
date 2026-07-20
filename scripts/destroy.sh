#!/bin/bash
# Usage: ./scripts/destroy.sh <lab-folder>
# Example: ./scripts/destroy.sh 01-ospf-ibgp
#
# Wipes a running fabric — destroys the containers and cleans up, leaving
# nothing running. Does NOT redeploy (use reset.sh for destroy + redeploy).

set -uo pipefail

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

cd "$(dirname "$TOPOLOGY")"

echo "Destroying lab: $LAB"
containerlab destroy -t "$(basename "$TOPOLOGY")" --cleanup

echo ""
echo "Done. Confirm nothing is left:"
echo "  docker ps | grep clab"
