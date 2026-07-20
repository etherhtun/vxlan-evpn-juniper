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

PREFIX="$(grep -m1 '^name:' "$TOPOLOGY" | awk '{print $2}')"

# Pre-flight: refuse if a DIFFERENT lab's fabric is running (only one fits).
OTHER="$(docker ps --format '{{.Names}}' 2>/dev/null | grep '^clab-' | grep -v "^clab-${PREFIX}-" || true)"
if [ -n "$OTHER" ]; then
  echo "ERROR: another fabric is running — wipe it before resetting '$LAB'."
  echo "$OTHER" | sed 's/^/  /'
  echo ""
  echo "Clear it:  sudo docker rm -f \$(docker ps -aq --filter name=clab-)"
  exit 1
fi

cd "$(dirname "$TOPOLOGY")"

echo "Destroying current lab..."
containerlab destroy -t "$(basename "$TOPOLOGY")" --cleanup 2>/dev/null || true

echo "Redeploying fresh..."
containerlab deploy -t "$(basename "$TOPOLOGY")"
