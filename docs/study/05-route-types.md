# 5 — EVPN route types

EVPN carries several **route types**, each a different kind of announcement. You
don't need all of them for lab 01, but knowing what each does is core knowledge
(and classic interview fodder).

## The five you should know

| Type | Name | Carries | Used for |
|------|------|---------|----------|
| **1** | Ethernet Auto-Discovery (A-D) | per-ES / per-EVI info | multihoming (ESI) — fast failover, aliasing |
| **2** | **MAC/IP Advertisement** | a host's MAC (+ optional IP) behind a VTEP | the workhorse — host reachability, ARP suppression |
| **3** | **Inclusive Multicast (IMET)** | "I have this VNI" | VTEP discovery + building the BUM flood list |
| **4** | Ethernet Segment | which VTEPs share an ES | multihoming — Designated Forwarder election |
| **5** | **IP Prefix** | an IP prefix (not tied to a MAC) | inter-subnet routing, L3VNI, external/summary routes |

For the labs, focus on **2, 3, 5**. Types 1 and 4 appear once you add multihoming.

## Type-3 (IMET) — the first thing you see

When a VTEP has a VNI with an active member, it advertises a **Type-3** route:
*"I participate in VNI 10100 — add me to the flood list for it."* Every VTEP
collects these to know **who to replicate BUM traffic to** (ingress replication,
lesson 3).

> **Order matters:** Type-3 is what appears *first*, before any host talks. In
> the lab, `bgp.evpn.0` showed the two Type-3 routes
> (`3:10.0.0.21:1::10100...` and `3:10.0.0.22:1::10100...`) as soon as the access
> port came up. A tunnel can't form until VTEPs discover each other via Type-3.

## Type-2 (MAC/IP) — the workhorse

When a VTEP learns a local host (from a frame, ARP, or DHCP), it advertises a
**Type-2** route: *"MAC aa:bb:cc — and IP 10.100.10.11 — is behind me (VTEP
10.0.0.22) in VNI 10100."*

This one route does a lot:
- Remote VTEPs install the MAC pointing at the tunnel to the origin VTEP.
- The IP portion feeds **ARP suppression** — a leaf can answer ARP locally.
- On a host move, a fresh Type-2 reconverges everything fast.

> In the lab, `show evpn database` showed the Type-2 entries once the hosts
> pinged, and `show ethernet-switching table` flagged the remote MAC **`DR`**
> (Dynamic Remote) via the VXLAN tunnel.

## Type-5 (IP Prefix) — routing, not bridging

Type-2 is about **MACs** (bridging within a subnet). **Type-5** advertises an
**IP prefix** with no MAC — used to route *between* subnets or to external
destinations, via an **L3VNI**. You reach for Type-5 when you need inter-VNI
routing, a default route to the internet, or route summarisation. (Later labs.)

## A quick way to remember them

> **Type-3 = presence** ("I'm here, I have this VNI").
> **Type-2 = endpoints** ("this exact host is behind me").
> **Type-5 = routing** ("reach this prefix through me").

## Reading a route in `show route table bgp.evpn.0`

```
3:10.0.0.21:1::10100::10.0.0.21/248
│  └ RD      └ VNI  └ originator VTEP
└ route type (3 = IMET)
```
The leading number is the **type**. Learn to read that first digit — it tells you
instantly what kind of announcement you're looking at.

## Check yourself

1. Which route type appears *first*, before any host sends traffic, and why?
2. What two things does a single Type-2 route enable?
3. When would you need a Type-5 route instead of a Type-2?
4. In `2:10.0.0.22:1::10100::aa:c1:...`, what does the leading `2` tell you?

→ Next: [Packet walk](06-packet-walk.md)
