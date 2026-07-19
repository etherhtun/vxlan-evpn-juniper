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
- [ ] `show route table bgp.evpn.0` — Type-3 (IMET) appears once access port is up
- [ ] `show ethernet-switching vxlan-tunnel-end-point remote` — RVTEP up, VNID 10100
- [ ] `show ethernet-switching table` — remote host MAC flagged `DR` via `vtep.32769`
- [ ] `show evpn database` — Type-2 (MAC/IP) for both hosts
- [ ] host1 → host2 ping succeeds across the fabric (0% loss)

> ✅ All checks confirmed on vJunos-switch 23.2R1.14 (2026-07-19). See
> [`LESSONS.md`](LESSONS.md) for gotchas — especially that Type-3 only appears
> once the VLAN has an up member (Step 5), not at Step 4.
