#!/bin/bash
# Usage: ./scripts/switch.sh <lab-folder>
# Example: ./scripts/switch.sh 01-ospf-ibgp
#
# Pushes a lab's full per-node config onto an ALREADY-RUNNING fabric, in
# parallel, then verifies. This is the "reset button" — it is NOT the learning
# path (for that, follow labs/<lab>/steps/ by hand).
#
# ── Junos vs the Cisco reference ───────────────────────────────────────────
# The NX-OS original pushed config as a MERGE (stale config from a higher
# session survived a downgrade). Junos gives us a clean atomic replace:
#   configure exclusive; load override terminal; <config>; commit and-quit
# So every switch.sh is a guaranteed clean state — no leftovers.
#
# configs/*.conf are therefore stored in Junos HIERARCHICAL (curly-brace)
# format, suitable for `load override`. (The steps/ docs teach the same thing
# in `set` format, which is friendlier to type by hand.)
#
# NOTE (validate on first real deploy):
#   - LAB_USER / LAB_PASS below must match the vJunos lab user created in the
#     topology's startup-config. Defaults are a guess.
#   - Confirm `load override terminal` + Ctrl-D over `ssh -tt` behaves; if not,
#     fall back to scp'ing the file and `load override <path>`.

set -euo pipefail

LAB="${1:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAB_USER="${LAB_USER:-admin}"
LAB_PASS="${LAB_PASS:-admin@123}"

if [ -z "$LAB" ]; then
  echo "Usage: $0 <lab-folder>"
  echo ""
  echo "Available labs:"
  ls "$REPO_ROOT/labs/" 2>/dev/null | sed 's/^/  /'
  echo ""
  echo "NOTE: switch.sh assumes the lab is already running (use deploy.sh first)."
  exit 1
fi

LAB_DIR="${REPO_ROOT}/labs/${LAB}"
CFG_DIR="${LAB_DIR}/configs"
TOPOLOGY="${LAB_DIR}/topology.clab.yml"

[ -d "$CFG_DIR" ]   || { echo "ERROR: no configs at $CFG_DIR"; exit 1; }
[ -f "$TOPOLOGY" ]  || { echo "ERROR: no topology at $TOPOLOGY"; exit 1; }
command -v sshpass >/dev/null 2>&1 || { echo "ERROR: install sshpass (sudo apt install -y sshpass)"; exit 1; }

PREFIX="$(grep -m1 '^name:' "$TOPOLOGY" | awk '{print $2}')"

# Auto-discover nodes from the .conf files present (skip hosts — Linux, no CLI).
NODES=()
for cfg in "$CFG_DIR"/*.conf; do
  [ -f "$cfg" ] || continue
  NODES+=("$(basename "$cfg" .conf)")
done
[ "${#NODES[@]}" -gt 0 ] || { echo "ERROR: no *.conf files in $CFG_DIR"; exit 1; }
echo "Pushing to: ${NODES[*]}"

echo ""
echo "==> Checking that lab is running..."
missing=0
for node in "${NODES[@]}"; do
  c="clab-${PREFIX}-${node}"
  if ! docker inspect "$c" >/dev/null 2>&1; then
    echo "  $c: NOT FOUND"; missing=$((missing+1))
  else
    state=$(docker inspect --format '{{.State.Status}}' "$c")
    echo "  $c: $state"
    [ "$state" != "running" ] && missing=$((missing+1))
  fi
done
[ "$missing" -eq 0 ] || { echo "ERROR: $missing node(s) not running."; exit 1; }

echo ""
echo "==> Waiting for Junos CLI (mgmt SSH) on all nodes..."
for node in "${NODES[@]}"; do
  c="clab-${PREFIX}-${node}"
  echo -n "  $node: "
  ok=0
  for _ in $(seq 1 60); do
    if sshpass -p "$LAB_PASS" ssh \
         -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
         -o LogLevel=ERROR -o ConnectTimeout=3 \
         -o PreferredAuthentications=password \
         "${LAB_USER}@${c}" "show system uptime" >/dev/null 2>&1; then
      ok=1; break
    fi
    sleep 3
  done
  [ "$ok" -eq 1 ] && echo "ready" || { echo "FAILED (no CLI after 180s)"; exit 1; }
done

echo ""
echo "==> Pushing $LAB configs in parallel (load override)..."
START=$(date +%s)
PUSH_LOG="${REPO_ROOT}/scripts/_push.log"
: > "$PUSH_LOG"

push_cfg() {
  local node="$1"
  local cfg="${CFG_DIR}/${node}.conf"
  local c="clab-${PREFIX}-${node}"
  [ -f "$cfg" ] || { echo "[$node] no cfg, skip" >> "$PUSH_LOG"; return; }
  echo "[$node] BEGIN push" >> "$PUSH_LOG"
  {
    echo "configure exclusive"
    echo "load override terminal"
    cat "$cfg"
    printf '\004'                 # Ctrl-D ends the terminal load
    echo "commit and-quit"
  } | sshpass -p "$LAB_PASS" ssh -tt \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o ConnectTimeout=10 \
        "${LAB_USER}@${c}" >> "$PUSH_LOG" 2>&1
  echo "[$node] END push (rc $?)" >> "$PUSH_LOG"
}

for node in "${NODES[@]}"; do push_cfg "$node" & done
wait
grep -E '^\[' "$PUSH_LOG" || true

echo ""
echo "==> Verifying config landed..."
# Per-lab marker: a string that only exists once this lab's config committed.
case "$LAB" in
  01-ospf-ibgp)  MARKER="family evpn signaling"; NODE="leaf1" ;;
  02-isis-ibgp)  MARKER="protocols isis";        NODE="leaf1" ;;
  03-ebgp-ibgp)  MARKER="family evpn signaling"; NODE="leaf1" ;;
  04-ebgp-ebgp)  MARKER="family evpn signaling"; NODE="leaf1" ;;
  *)             MARKER="";                       NODE="leaf1" ;;
esac
if [ -n "$MARKER" ]; then
  c="clab-${PREFIX}-${NODE}"
  if sshpass -p "$LAB_PASS" ssh \
       -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o LogLevel=ERROR "${LAB_USER}@${c}" \
       "show configuration | display set | match \"$MARKER\"" 2>/dev/null | grep -q "$MARKER"; then
    echo "  Config OK on $NODE (found: $MARKER)"
  else
    echo "  WARNING: marker '$MARKER' missing on $NODE. Inspect: cat $PUSH_LOG"
  fi
fi

echo ""
echo "============================================================"
echo "Switched to lab $LAB in $(( $(date +%s) - START ))s"
echo "============================================================"

# Per-lab host setup hints (containerlab Linux hosts).
case "$LAB" in
  01-ospf-ibgp)
    cat <<'HOSTS'

Host setup (VLAN 100 / 10.100.10.0/24):
  docker exec clab-PREFIX-host1 sh -c "ip addr flush dev eth1; ip addr add 10.100.10.10/24 dev eth1; ip link set eth1 up"
  docker exec clab-PREFIX-host2 sh -c "ip addr flush dev eth1; ip addr add 10.100.10.11/24 dev eth1; ip link set eth1 up"

Test:  docker exec clab-PREFIX-host1 ping -c 3 10.100.10.11
HOSTS
    ;;
esac
