# Lab 02 (RR) — Verification checklist

Same layered checks as lab 01, with the RR-specific overlay checks called out.

## Underlay (OSPF) — identical to lab 01
- [ ] `show ospf neighbor` — every fabric link `Full`
- [ ] `ping 10.0.0.22 source 10.0.0.21` — leaf-to-leaf loopback reachable

## Overlay (RR) — the difference
- [ ] **On a leaf:** `show bgp summary` — peers to **both spines** (`10.0.0.11`,
      `10.0.0.12`) `Establ`; no leaf-to-leaf session
- [ ] **On a spine:** `show bgp summary` — peers to **both leaves**, `Establ`
      (the spine now runs BGP-EVPN, unlike lab 01)
- [ ] ⭐ **On a spine:** `show route table bgp.evpn.0` — EVPN routes **present**
      (the RR retains and reflects them)

## EVPN / VXLAN — identical to lab 01
- [ ] `show route table bgp.evpn.0` on a leaf — Type-3 then Type-2 routes
- [ ] `show ethernet-switching vxlan-tunnel-end-point remote` — tunnel up
- [ ] ⭐ **On a leaf:** `show route table bgp.evpn.0 extensive | match "Protocol next hop"`
      — next-hop is the far **leaf** loopback, **not** a spine

## Services (data plane) — identical to lab 01
- [ ] host1 → host2 ping succeeds (0% loss) — proves data plane is leaf-to-leaf

> The two ⭐ checks are what make this *production RR* rather than just "more
> BGP sessions": the spine holds/reflects routes, but never sits in the data path.
