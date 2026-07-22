#!/bin/bash
# Usage: ./scripts/apply.sh <lab-folder> <step|all>
#
# Applies a single lab step (or all steps in order) to the running fabric,
# incrementally. Each step is a set of per-node `.set` snippets under
# labs/<lab>/apply/ named  <NN>-<node>.set  (e.g. 02-leaf1.set).
#
# Examples:
#   ./scripts/apply.sh 01-ospf-ibgp 01     # just Step 1 (fabric) on all its nodes
#   ./scripts/apply.sh 01-ospf-ibgp 03     # just Step 3 (needs 01+02 already applied)
#   ./scripts/apply.sh 01-ospf-ibgp 01-03  # Steps 01 through 03 in order (a range)
#   ./scripts/apply.sh 01-ospf-ibgp all    # Steps 01→05 in order (full build)
#
# Steps are CUMULATIVE — each builds on the one below. To be "at" step N on a fresh
# fabric, apply 01..N (use a range like 01-0N or 'all').
#
# Snippets are `set` format, sent directly as config-mode commands (additive),
# so steps stack. For a guaranteed clean slate, use ./scripts/reset.sh first.
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

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR -o ConnectTimeout=8
          -o PreferredAuthentications=password)

FAILED=()   # nodes whose commit did not persist (populated by push)

# Wait until the node's Junos CLI answers (post-reset boot can take minutes).
# Plain ssh (no -tt) + hard timeout so a stuck session can never hang us.
wait_cli() {
  local c="$1" i
  for i in $(seq 1 40); do
    if timeout 12 sshpass -p "$LAB_PASS" ssh "${SSH_OPTS[@]}" \
         "${LAB_USER}@${c}" "show system uptime" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}

# One config push: set lines directly in config mode (no load-set-terminal/^D).
do_push() {
  local c="$1" file="$2"
  { echo "configure"
    echo "rollback 0"
    grep -E '^(set|delete|deactivate|activate) ' "$file"
    echo "commit and-quit"
    echo "exit"
  } | timeout 90 sshpass -p "$LAB_PASS" ssh -tt "${SSH_OPTS[@]}" \
        "${LAB_USER}@${c}" 2>&1
}

# ⭐ Verify a step actually PERSISTED (guards against silent commit loss on a
# loaded VM). Checks the running config for the step's first `set` statement.
verify_committed() {
  local c="$1" marker="$2"
  [ -n "$marker" ] || return 0
  timeout 20 sshpass -p "$LAB_PASS" ssh "${SSH_OPTS[@]}" "${LAB_USER}@${c}" \
    "show configuration | display set | match \"$marker\"" 2>/dev/null | grep -qF "$marker"
}

# Push one node's snippet, verify it landed, retry once, else record failure.
push() {
  local node="$1" file="$2"
  local c="clab-${PREFIX}-${node}"
  echo -n "    $node ... "
  if ! docker inspect "$c" >/dev/null 2>&1; then echo "container not found"; FAILED+=("$node"); return 0; fi
  if ! wait_cli "$c"; then echo "CLI not ready (boot still in progress?)"; FAILED+=("$node"); return 0; fi

  local marker; marker="$(grep -m1 '^set ' "$file" | sed 's/^set //')"
  local out; out="$(do_push "$c" "$file")" || true
  if verify_committed "$c" "$marker"; then echo "committed"; return 0; fi

  # Not persisted — one retry (common under transient load).
  out="$(do_push "$c" "$file")" || true
  if verify_committed "$c" "$marker"; then echo "committed (retry)"; return 0; fi

  echo "FAILED — commit did not persist:"
  echo "$out" | grep -iE 'error|constraint|commit' | sed 's/^/        /' | tail -6
  FAILED+=("$node")
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
elif [[ "$STEP" =~ ^[0-9]+-[0-9]+$ ]]; then
  # Range, e.g. "01-03" — apply those steps in order (steps are cumulative, so the
  # low end must include the prerequisites, i.e. start at 01 on a fresh fabric).
  lo="${STEP%-*}"; hi="${STEP#*-}"
  for n in $(seq "$((10#$lo))" "$((10#$hi))"); do apply_step "$(printf '%02d' "$n")"; done
else
  apply_step "$(printf '%02d' "$((10#${STEP}))" 2>/dev/null || echo "$STEP")"
fi

echo ""
if [ "${#FAILED[@]}" -gt 0 ]; then
  # de-duplicate the failed list
  UNIQ_FAILED="$(printf '%s\n' "${FAILED[@]}" | sort -u | tr '\n' ' ')"
  echo "❌ FAILED to persist config on: ${UNIQ_FAILED}"
  echo "   Re-run this command (idempotent), or: ./scripts/reset.sh ${LAB} && ./scripts/apply.sh ${LAB} all"
  echo "   Repeated failures usually mean the host is low on RAM — check 'free -h' on the"
  echo "   clab host; a 2x2 vJunos fabric wants a VM with plenty of headroom (≥ n2-standard-16)."
  echo ""
fi
echo "Done. Verify with the matching labs/${LAB}/steps/ doc."
case "$STEP" in
  *05|5|all) HOST_HINT=1 ;; *) HOST_HINT="" ;;
esac
if [ -n "$HOST_HINT" ]; then
  cat <<HOSTS

Step 5b — host IPs (run on the clab host shell, NOT the Junos CLI):
  docker exec clab-${PREFIX}-host1 sh -c "ip addr add 10.100.10.10/24 dev eth1; ip link set eth1 up"
  docker exec clab-${PREFIX}-host2 sh -c "ip addr add 10.100.10.11/24 dev eth1; ip link set eth1 up"
  docker exec clab-${PREFIX}-host1 ping -c3 10.100.10.11
HOSTS
fi
