#!/bin/bash
# Usage: ./scripts/apply.sh <lab-folder> <step|all>
#
# Applies a single lab step (or all steps in order) to the running fabric,
# incrementally. Each step is a set of per-node `.set` snippets under
# labs/<lab>/apply/ named  <NN>-<node>.set  (e.g. 02-leaf1.set).
#
# Examples:
#   ./scripts/apply.sh 01-ospf-ibgp 01     # just Step 1 (fabric) on all its nodes
#   ./scripts/apply.sh 01-ospf-ibgp 03     # Step 3 (overlay) on leaf1+leaf2
#   ./scripts/apply.sh 01-ospf-ibgp all    # Steps 01→05 in order (full build)
#
# Snippets are `set` format, loaded with `load set terminal` (additive), so
# steps stack. For a guaranteed clean slate, use ./scripts/reset.sh first.
#
# NOTE: no `set -e` here on purpose — Junos CLI over `ssh -tt` returns non-zero
# routinely, and we handle failures explicitly per node.

set -uo pipefail

LAB="${1:-}"
STEP="${2:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAB_USER="${LAB_USER:-admin}"
LAB_PASS="${LAB_PASS:-admin@123}"

if [ -z "$LAB" ] || [ -z "$STEP" ]; then
  echo "Usage: $0 <lab-folder> <step|all>"
  echo ""
  echo "Available labs:"
  ls "$REPO_ROOT/labs/" 2>/dev/null | sed 's/^/  /'
  exit 1
fi

LAB_DIR="${REPO_ROOT}/labs/${LAB}"
APPLY_DIR="${LAB_DIR}/apply"
TOPOLOGY="${LAB_DIR}/topology.clab.yml"
[ -d "$APPLY_DIR" ]  || { echo "ERROR: no apply/ dir at $APPLY_DIR"; exit 1; }
[ -f "$TOPOLOGY" ]   || { echo "ERROR: no topology at $TOPOLOGY"; exit 1; }
command -v sshpass >/dev/null 2>&1 || { echo "ERROR: install sshpass (sudo apt install -y sshpass)"; exit 1; }

PREFIX="$(grep -m1 '^name:' "$TOPOLOGY" | awk '{print $2}')"

ssh_node() {   # ssh_node <container> <remote-cli-command>
  sshpass -p "$LAB_PASS" ssh -tt \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR -o ConnectTimeout=10 \
    -o PreferredAuthentications=password "${LAB_USER}@$1" "$2" 2>&1
}

# Wait until the node's Junos CLI answers (post-reset boot can take minutes).
wait_cli() {
  local c="$1" i
  for i in $(seq 1 40); do
    if ssh_node "$c" "show system uptime" 2>/dev/null | grep -qi 'uptime\|current time'; then
      return 0
    fi
    sleep 3
  done
  return 1
}

# Push one node's snippet: load set terminal + commit.
push() {
  local node="$1" file="$2"
  local c="clab-${PREFIX}-${node}"
  echo -n "    $node ... "
  if ! docker inspect "$c" >/dev/null 2>&1; then echo "container not found"; return 0; fi
  if ! wait_cli "$c"; then echo "CLI not ready (boot still in progress?)"; return 0; fi

  local out=""
  out=$( { echo "configure exclusive"
           echo "load set terminal"
           cat "$file"
           printf '\004'                 # Ctrl-D ends the terminal load
           echo "commit and-quit"
         } | sshpass -p "$LAB_PASS" ssh -tt \
               -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
               -o LogLevel=ERROR -o ConnectTimeout=10 \
               -o PreferredAuthentications=password "${LAB_USER}@${c}" 2>&1 ) || true

  if echo "$out" | grep -qi 'commit complete'; then
    echo "committed"
  elif echo "$out" | grep -qi 'commit.*not needed\|no changes'; then
    echo "no change (already applied)"
  else
    echo "CHECK — no 'commit complete' seen:"
    echo "$out" | sed 's/^/        /' | tail -10
  fi
}

# Apply one step number (e.g. "01") — every <NN>-<node>.set for it.
apply_step() {
  local nn="$1"
  local files=( "$APPLY_DIR/${nn}-"*.set )
  [ -e "${files[0]}" ] || { echo "  Step $nn: no snippets, skipping"; return; }
  echo "  Step $nn:"
  for f in "${files[@]}"; do
    local node; node="$(basename "$f" .set | sed "s/^${nn}-//")"
    push "$node" "$f"
  done
}

if [ "$STEP" = "all" ]; then
  STEPS=$(ls "$APPLY_DIR"/*.set 2>/dev/null | sed -E 's#.*/([0-9]+)-.*#\1#' | sort -u)
  for nn in $STEPS; do apply_step "$nn"; done
else
  apply_step "$(printf '%02d' "$((10#${STEP}))" 2>/dev/null || echo "$STEP")"
fi

echo ""
echo "Done. Verify with the matching labs/${LAB}/steps/ doc."
if [ "$STEP" = "05" ] || [ "$STEP" = "5" ] || [ "$STEP" = "all" ]; then
  cat <<HOSTS

Step 5b — host IPs (run on the clab host shell, NOT the Junos CLI):
  docker exec clab-${PREFIX}-host1 sh -c "ip addr add 10.100.10.10/24 dev eth1; ip link set eth1 up"
  docker exec clab-${PREFIX}-host2 sh -c "ip addr add 10.100.10.11/24 dev eth1; ip link set eth1 up"
  docker exec clab-${PREFIX}-host1 ping -c3 10.100.10.11
HOSTS
fi
