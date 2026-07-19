# Step 3 — Overlay: iBGP-EVPN (full mesh)

## Concept
Now the leaves peer **loopback-to-loopback** and carry the `evpn` address
family. In this full-mesh design the **leaves are the VTEPs and peer directly
with each other**; the spines stay pure IP transport and run no EVPN. With two
leaves that is a single iBGP session.

## Config (draft — validate on live fabric)
On **leaf1**:
```
set routing-options autonomous-system 65000
set protocols bgp group overlay type internal
set protocols bgp group overlay local-address 10.0.0.21
set protocols bgp group overlay family evpn signaling
set protocols bgp group overlay neighbor 10.0.0.22        # leaf2
```
leaf2 is the mirror (`local-address 10.0.0.22`, `neighbor 10.0.0.21`).

## Verify
```
show bgp summary
   → peer 10.0.0.22, state "Establ", family evpn negotiated
```
Session up with **0 routes is correct here** — no VXLAN is defined yet.

## Checkpoint
BGP EVPN session `Established` → proceed to Step 4.
