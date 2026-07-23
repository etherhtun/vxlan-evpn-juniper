#!/bin/bash
# Usage: ./scripts/clean.sh <lab-folder>
# Example: ./scripts/clean.sh 01-ospf-ibgp
#
# Wipes a lab's CONFIG back to the blank baseline on all switch nodes WITHOUT
# rebooting the containers — a ~30-second reset instead of the ~8-30 min that
# reset.sh (destroy + redeploy) costs. The management user/interface is kept, so
# you don't lock yourself out. After clean, re-apply with ./scripts/apply.sh.
#
# Use this for iterating within a running lab. Use reset.sh only when you truly
# need fresh containers (e.g. a wedged node), or destroy.sh to tear everything down.

set -uo pipefail

LAB="${1:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAB_USER="${LAB_USER:-admin}"
LAB_PASS="${LAB_PASS:-admin@123}"

if [ -z "$LAB" ]; then
  echo "Usage: $0 <lab-folder>"
  echo ""
  echo "Available labs:"
  ls "$REPO_ROOT/labs/" 2>/dev/null | sed 's/^/  /'
  exit 1
fi

LAB_DIR="${REPO_ROOT}/labs/${LAB}"
CFG_DIR="${LAB_DIR}/configs"
TOPOLOGY="${LAB_DIR}/topology.clab.yml"
[ -f "$TOPOLOGY" ] || { echo "ERROR: no topology at $TOPOLOGY"; exit 1; }
command -v sshpass >/dev/null 2>&1 || { echo "ERROR: install sshpass (sudo apt install -y sshpass)"; exit 1; }

PREFIX="$(grep -m1 '^name:' "$TOPOLOGY" | awk '{print $2}')"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR -o ConnectTimeout=8 -o PreferredAuthentications=password)

# The config hierarchies the labs add. `delete` tolerates "statement not found",
# so this is safe whether or not a given lab used a hierarchy. Management config
# (system login, fxp0) is NOT touched.
read -r -d '' CLEAN <<'EOF' || true
delete interfaces ge-0/0/0
delete interfaces ge-0/0/1
delete interfaces ge-0/0/2
delete interfaces ge-0/0/3
delete interfaces ge-0/0/4
delete interfaces irb
delete interfaces ae0
delete interfaces lo0 unit 0
delete protocols ospf
delete protocols isis
delete protocols bgp
delete protocols evpn
delete switch-options
delete vlans
delete routing-instances
delete routing-options router-id
delete routing-options autonomous-system
delete routing-options graceful-restart
delete policy-options
delete chassis aggregated-devices
delete forwarding-options storm-control-profiles
delete firewall
EOF

# Discover switch nodes from configs/ (Linux hosts have no .conf → skipped).
NODES=()
if [ -d "$CFG_DIR" ]; then
  for cfg in "$CFG_DIR"/*.conf; do [ -f "$cfg" ] && NODES+=("$(basename "$cfg" .conf)"); done
fi
[ "${#NODES[@]}" -gt 0 ] || { echo "ERROR: no switch configs in $CFG_DIR"; exit 1; }

echo "Cleaning lab config (no reboot) on: ${NODES[*]}"
for node in "${NODES[@]}"; do
  c="clab-${PREFIX}-${node}"
  echo -n "  $node ... "
  if ! docker inspect "$c" >/dev/null 2>&1; then echo "container not found (deploy first?)"; continue; fi
  out="$( { echo "configure"; echo "rollback 0"; printf '%s\n' "$CLEAN"; echo "commit and-quit"; echo "exit"; } \
          | timeout 90 sshpass -p "$LAB_PASS" ssh -tt "${SSH_OPTS[@]}" "${LAB_USER}@${c}" 2>&1 )" || true
  if echo "$out" | grep -qi 'commit complete'; then echo "cleaned"; else
    echo "CHECK:"; echo "$out" | grep -iE 'error|commit' | sed 's/^/      /' | tail -4
  fi
done

# Flush the containerlab hosts' data interfaces too (best-effort).
for h in host1 host2; do
  c="clab-${PREFIX}-${h}"
  docker inspect "$c" >/dev/null 2>&1 && docker exec "$c" sh -c 'ip addr flush dev eth1 2>/dev/null; ip addr flush dev eth2 2>/dev/null' 2>/dev/null && echo "  $h: interfaces flushed"
done

echo ""
echo "Config wiped to baseline. Rebuild with: ./scripts/apply.sh ${LAB} all"
