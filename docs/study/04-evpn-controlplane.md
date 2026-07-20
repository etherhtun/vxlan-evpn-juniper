# 4 — EVPN control plane

Lesson 3 showed *how* a frame crosses the fabric. This lesson answers: **how does
a VTEP know where to send it?** That's the control plane — and it's what makes
VXLAN-EVPN better than plain VXLAN.

## The problem EVPN solves

Plain VXLAN (without EVPN) still does **flood-and-learn**, just like old L2: to
find an unknown MAC, flood everywhere and learn from the replies. That doesn't
scale and wastes bandwidth.

**EVPN replaces flooding with advertising.** Each VTEP *tells* the others which
MACs and IPs live behind it — using BGP. No discovery-by-flooding.

## EVPN is a BGP address family

EVPN isn't a new protocol — it's a new **address family carried in MP-BGP**:

- `family evpn signaling` in Junos / `address-family l2vpn evpn` in Cisco.
- Technically **AFI 25 (L2VPN), SAFI 70 (EVPN)**.
- It rides on the same BGP sessions you already run — in the lab, the iBGP
  session between the leaf loopbacks.

So the leaves peer over BGP and exchange **EVPN routes** (covered next lesson)
that say things like *"MAC aa:bb:cc, IP 10.100.10.11, is behind VTEP 10.0.0.22,
in VNI 10100."*

## Two identifiers you must know: RD and RT

These trip people up. Learn them cold — they're guaranteed interview material.

### Route Distinguisher (RD)
- Makes each VTEP's routes **unique**. Two leaves might both advertise
  `10.100.10.0/24`; without an RD those look identical in BGP.
- Prepended to the route: e.g. `10.0.0.21:1`. Purely for **uniqueness**.
- In the lab, each leaf had a *different* RD (`10.0.0.21:1` vs `10.0.0.22:1`).

### Route Target (RT)
- An extended community that controls **import/export** — *which* VTEPs/VRFs
  should accept a route.
- A VTEP **exports** routes tagged with an RT, and **imports** routes matching
  its configured RT. Same RT = same virtual network.
- In the lab, both leaves shared the *same* RT (`target:65000:1`) — that's how
  they agreed to be in one VNI.

> **RD = uniqueness. RT = membership.** Different RD per box, shared RT per VNI.

## What EVPN gives you (beyond just "no flooding")

| Feature | What it does |
|---------|--------------|
| **MAC/IP advertising** | Learn remote hosts via BGP (Type-2), not flooding |
| **ARP/ND suppression** | The local leaf answers ARP from its EVPN table — the ARP never crosses the fabric |
| **Fast convergence** | A host move is a BGP update, not a flood-and-relearn |
| **Multihoming (ESI)** | A host can connect to two leaves, both active (all-active) |
| **Integrated Routing & Bridging (IRB)** | Route between VNIs on the leaf (L3VNI), anycast gateway |

## iBGP vs eBGP for the overlay

- **iBGP** (lab 01): all VTEPs in one AS. Full mesh — or, at scale, spines act as
  **route reflectors** so you don't need N² sessions.
- **eBGP** (lab 04): each leaf its own AS; the overlay uses eBGP-EVPN. Common in
  large fabrics because one protocol (eBGP) can do both underlay and overlay.

This overlay choice is the axis labs 01–04 explore.

## Check yourself

1. What does EVPN replace, and with what?
2. EVPN is carried in which protocol, as what?
3. Explain RD vs RT — which is unique per box, which is shared per VNI, and why?
4. What is ARP suppression and why is it valuable?

→ Next: [EVPN route types](05-route-types.md)
