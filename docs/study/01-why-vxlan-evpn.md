# 1 — Why VXLAN-EVPN?

Before *how*, understand *why*. VXLAN-EVPN exists because traditional Layer-2
networks hit hard walls in the data center.

## The problems with a classic L2 (VLAN + spanning tree) network

| Problem | Why it hurts |
|---------|--------------|
| **Spanning Tree blocks links** | STP prevents loops by *disabling* redundant links. In a fabric with many paths, you're paying for links you can't use — no load balancing. |
| **VLAN limit = 4094** | The 802.1Q tag is 12 bits. A multi-tenant cloud needs far more than 4094 segments. |
| **MAC table scale** | Every switch must learn *every* MAC in the L2 domain. Big flat networks overflow hardware tables. |
| **Large failure domains** | A broadcast storm or loop takes down the whole L2 domain. |
| **No workload mobility** | A VM tied to a subnet can't move to another rack without re-IP or stretched VLANs (which make the above worse). |

## What the data center actually needs

- **Use every link** — equal-cost multipath (ECMP), no blocked ports.
- **Massive scale** — millions of segments, not thousands.
- **Any workload anywhere** — a VM can live on any leaf and keep its IP.
- **Multi-tenancy** — many isolated tenants sharing the same physical fabric.
- **Small failure domains** — a problem on one leaf stays there.

## How VXLAN-EVPN delivers it

**VXLAN** (the data plane) wraps Ethernet frames inside UDP/IP so Layer-2 can
ride over a **routed** Layer-3 network:

- The L3 underlay uses normal routing (OSPF/IS-IS/BGP) → **ECMP, all links active,
  no spanning tree** between leaves and spines.
- The segment ID (VNI) is **24 bits → ~16 million** segments, not 4094.
- Because it's routed underneath, a host's L2 segment can be **stretched to any
  leaf** — workload mobility.

**EVPN** (the control plane) replaces the old "flood and learn" with BGP:

- VTEPs **advertise** their local MACs/IPs to each other via BGP, instead of
  flooding to discover them.
- Enables **ARP suppression**, fast convergence, multihoming, and integrated
  routing/bridging.

## The one-liner to remember

> **VLANs made one wire look like many. VXLAN makes many wires (a whole routed
> fabric) look like one — and EVPN keeps track of who's on it.**

## Check yourself

1. Why can't a spanning-tree network use all its links, and how does a routed
   underlay fix that?
2. What's the hard numeric limit on VLANs, and what's VXLAN's equivalent?
3. In one sentence each: what does **VXLAN** do vs what does **EVPN** do?

→ Next: [Underlay vs overlay](02-underlay-overlay.md)
