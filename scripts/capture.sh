#!/bin/bash
# Usage: ./scripts/capture.sh <node> <interface> <output-name> [tcpdump-filter]
#
# Captures packets on a clab node's interface into a .pcap for Wireshark.
# The classic VXLAN filter is 'udp port 4789'.
#
# Examples:
#   ./scripts/capture.sh leaf1 eth1 04-vxlan-encap 'udp port 4789'
#   ./scripts/capture.sh spine1 eth1 02-underlay 'ospf or icmp'
#
# NOTE: <node>:<interface> is the *containerlab* side (eth1, eth2, ...), which
# is where the VXLAN-encapsulated frame is visible on the wire. That is what
# you want — the outer UDP/4789 header only exists on the fabric links.

set -euo pipefail

NODE="${1:-}"
IFACE="${2:-}"
OUTNAME="${3:-}"
FILTER="${4:-}"
COUNT="${COUNT:-50}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$NODE" ] || [ -z "$IFACE" ] || [ -z "$OUTNAME" ]; then
  echo "Usage: $0 <node> <interface> <output-name> [tcpdump-filter]"
  echo ""
  echo "Examples:"
  echo "  $0 leaf1 eth1 04-vxlan-encap 'udp port 4789'"
  echo "  $0 spine1 eth1 02-underlay 'ospf or icmp'"
  echo ""
  echo "Env: COUNT=<n>  packets to capture (default 50)"
  exit 1
fi

# Derive the clab container prefix from any topology's name: field.
PREFIX="$(grep -hm1 '^name:' "$REPO_ROOT"/labs/*/topology.clab.yml 2>/dev/null | head -1 | awk '{print $2}')"
CONTAINER="clab-${PREFIX}-${NODE}"

# Save into the current lab's pcaps/ if we are inside one, else repo pcaps/.
if [[ "$(pwd)" == *"/labs/"* ]]; then
  PCAP_DIR="$(pwd | sed -E 's|(.*/labs/[^/]+).*|\1|')/pcaps"
else
  PCAP_DIR="${REPO_ROOT}/pcaps"
fi
mkdir -p "$PCAP_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
PCAP_FILE="${PCAP_DIR}/${OUTNAME}-${TS}.pcap"

echo "Capturing on ${CONTAINER}:${IFACE}"
echo "Filter: ${FILTER:-<none>}   Count: ${COUNT}"
echo "Output: ${PCAP_FILE}"
echo ""
echo "Trigger your traffic now (e.g. start a ping in another terminal)."
echo "Stops after ${COUNT} packets or Ctrl-C."
echo ""

sudo docker exec "$CONTAINER" tcpdump -i "$IFACE" -nn -e -U -w - ${FILTER:+$FILTER} -c "$COUNT" 2>/dev/null > "$PCAP_FILE"

echo ""
echo "Saved: $PCAP_FILE ($(du -h "$PCAP_FILE" | cut -f1))"
echo "Preview: tcpdump -r ${PCAP_FILE} -nn -e | head -20"
