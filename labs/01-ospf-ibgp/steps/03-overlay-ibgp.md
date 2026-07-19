# Step 3 — Overlay: iBGP-EVPN (full mesh)

## Concept
Now the leaves peer **loopback-to-loopback** and carry the `evpn` address
family. In this full-mesh design the **leaves are the VTEPs and peer directly
with each other**; the spines stay pure IP transport and run no EVPN. With two
leaves that is a single iBGP session.

```mermaid
graph TB
    S1["spine1<br/>underlay only"]
    S2["spine2<br/>underlay only"]
    L1["leaf1<br/>10.0.0.21"]
    L2["leaf2<br/>10.0.0.22"]
    S1 -.-> L1
    S1 -.-> L2
    S2 -.-> L1
    S2 -.-> L2
    L1 ===|"iBGP-EVPN · AS 65000<br/>lo0 ↔ lo0"| L2

    classDef spine fill:#eeeeee,stroke:#9e9e9e,color:#616161;
    class S1,S2 spine;
```

Dotted = physical underlay paths (spines just forward IP). Thick line = the
single EVPN control-plane session between the two VTEPs. The session rides *over*
the underlay — it doesn't touch the spines' BGP (they have none).

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
