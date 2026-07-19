# Lab 01 — Verification checklist

Work top-down. Each check gates the next; a failure localises the fault to
that layer.

## Underlay (OSPF)
- [ ] `show ospf neighbor` — every fabric link `Full`
- [ ] `ping 10.0.0.22 source 10.0.0.21` — leaf-to-leaf loopback reachable

## Overlay (BGP)
- [ ] `show bgp summary` — EVPN peer `Established`, `evpn` family negotiated

## EVPN / VXLAN
- [ ] `show route table bgp.evpn.0` — Type-3 (IMET) route from the peer leaf
- [ ] `show ethernet-switching vxlan-tunnel-end-point remote` — tunnel up

## Services (data plane)
- [ ] `show ethernet-switching table` — remote host MAC via VTEP, not a port
- [ ] `show evpn database` — Type-2 (MAC/IP) for both hosts
- [ ] host1 → host2 ping succeeds across the fabric

> STUB — exact expected output snippets get pasted in after the first live run.
