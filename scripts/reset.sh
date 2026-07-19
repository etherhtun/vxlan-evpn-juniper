#!/bin/bash
# Usage: ./scripts/reset.sh <lab-folder>
# Example: ./scripts/reset.sh 01-ospf-ibgp
#
# Destroys and redeploys the named lab for a clean start.

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
  exit 1
fi

cd "$(dirname "$TOPOLOGY")"

echo "Destroying current lab..."
containerlab destroy -t "$(basename "$TOPOLOGY")" --cleanup 2>/dev/null || true

echo "Redeploying fresh..."
containerlab deploy -t "$(basename "$TOPOLOGY")"
