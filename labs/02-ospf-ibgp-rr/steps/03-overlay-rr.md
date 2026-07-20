# Step 3 (RR) — Overlay: iBGP-EVPN with spine route-reflectors

This is the only step that differs from lab 01. Instead of the leaves peering
directly with each other, **every leaf peers with both spines**, and the
**spines reflect** EVPN routes between the leaves.

## Concept
- **Spines** run BGP-EVPN with a `cluster` id → that makes them **route
  reflectors**. They carry EVPN routes and relay them between clients, but they
  have **no `switch-options` / `vlans`** — they are **not** VTEPs.
- **Leaves** peer only with the two spines (2 sessions each, regardless of how
  many leaves the fabric grows to). They remain the VTEPs.
- **Next-hop is preserved** through reflection, so the VXLAN tunnel stays
  leaf-to-leaf. The spine is control-plane only.

## Config — spines (route reflectors)
**spine1** (spine2 mirrors with its own `local-address`/`cluster` = 10.0.0.12):
```
set routing-options autonomous-system 65000
set protocols bgp group overlay type internal
set protocols bgp group overlay local-address 10.0.0.11
set protocols bgp group overlay family evpn signaling
set protocols bgp group overlay cluster 10.0.0.11        # ← makes it an RR
set protocols bgp group overlay neighbor 10.0.0.21       # leaf1 (client)
set protocols bgp group overlay neighbor 10.0.0.22       # leaf2 (client)
```

## Config — leaves (RR clients)
**leaf1** (leaf2 mirrors with `local-address 10.0.0.22`):
```
set routing-options autonomous-system 65000
set protocols bgp group overlay type internal
set protocols bgp group overlay local-address 10.0.0.21
set protocols bgp group overlay family evpn signaling
set protocols bgp group overlay neighbor 10.0.0.11       # spine1 (RR)
set protocols bgp group overlay neighbor 10.0.0.12       # spine2 (RR)
```
Or just: `./scripts/apply.sh 02-ospf-ibgp-rr 03`

## Verify — three checks

**1. Leaves peer to both spines** (leaf1):
```
show bgp summary        → peers 10.0.0.11 and 10.0.0.12, both Establ
```

**2. ⭐ OPEN CHECK — the spine retains & reflects EVPN routes** (spine1, *after* Step 4/5):
```
show route table bgp.evpn.0     → Type-2/Type-3 routes PRESENT
```
This is the one thing to confirm on first live run. A route reflector that isn't
a VTEP has no routing-instance to import routes into — on Junos the routes should
still sit in `bgp.evpn.0` and be reflected, but **if this table is empty**, the
RR is discarding them and we add on each spine:
```
set protocols bgp group overlay family evpn signaling   # (already present)
# fix if needed — force the RR to keep routes with no local import:
set routing-options resolution rib bgp.evpn.0 ...        # OR a keep-all knob
```
> Update this doc once confirmed on the live fabric.

**3. ⭐ Data plane still leaf-to-leaf** (leaf1, after hosts are up):
```
show route table bgp.evpn.0 extensive | match "Protocol next hop"
   → next-hop = 10.0.0.22 (leaf2), NOT a spine
```
Proves the spine reflects control only; the VXLAN tunnel bypasses it.

## Checkpoint
Leaves ↔ both spines `Establ`, spine holds EVPN routes, host ping works with
leaf-to-leaf next-hop → RR overlay is production-correct. Continue to
[Step 4](../../01-ospf-ibgp/steps/04-evpn-vxlan.md) (identical to lab 01).
