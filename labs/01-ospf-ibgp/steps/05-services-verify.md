# Step 5 — Services: attach hosts & prove it end-to-end

## Concept
Put a host-facing port into VLAN 100 on each leaf, address the two containerlab
hosts in the same subnet, and generate traffic. When a host MAC is learned, a
**Type-2 (MAC/IP)** route appears in EVPN and is advertised to the far leaf —
that is the "it works" moment: the remote MAC is reachable via a VXLAN tunnel,
not a local wire.

## 5a. Access ports ✅ (validated) — on each leaf
```
set interfaces ge-0/0/2 unit 0 family ethernet-switching interface-mode access
set interfaces ge-0/0/2 unit 0 family ethernet-switching vlan members v100
```
Or: `./scripts/apply.sh 01-ospf-ibgp 05`

**The moment this commits, the Type-3 (IMET) route appears** (VLAN 100 now has an
up member). Confirm on leaf2:
```
show route table bgp.evpn.0
```
```
3:10.0.0.21:1::10100::10.0.0.21/248 IM   ← from leaf1 (note two next-hops = spine ECMP)
3:10.0.0.22:1::10100::10.0.0.22/248 IM   ← leaf2's own
```
And the tunnel:
```
show ethernet-switching vxlan-tunnel-end-point remote
   → RVTEP-IP 10.0.0.21 via vtep.32769, VNID 10100
```

## 5b. Address the hosts — from the **clab host shell** (not Junos CLI)
```
docker exec clab-vxlan-evpn-jnpr-host1 sh -c "ip addr add 10.100.10.10/24 dev eth1; ip link set eth1 up"
docker exec clab-vxlan-evpn-jnpr-host2 sh -c "ip addr add 10.100.10.11/24 dev eth1; ip link set eth1 up"
docker exec clab-vxlan-evpn-jnpr-host1 ping -c3 10.100.10.11
```
Confirmed — **0% packet loss** across the VXLAN fabric 🎉:
```
64 bytes from 10.100.10.11: seq=0 ttl=64 time=9.7 ms   (3 received, 0% loss)
```

## Verify Type-2 (MAC learning) on leaf1
```
show evpn database
   10100  aa:c1:ab:cf:00:a6  10.0.0.22    10.100.10.11   ← host2 via leaf2's VTEP (remote)
   10100  aa:c1:ab:e9:b3:87  ge-0/0/2.0   10.100.10.10   ← host1 (local)

show ethernet-switching table
   v100  aa:c1:ab:cf:00:a6  DR  vtep.32769   ← flag DR = Dynamic Remote (over the tunnel)
   v100  aa:c1:ab:e9:b3:87  D   ge-0/0/2.0
```

## Checkpoint
Cross-fabric host ping succeeds + Type-2 MACs learned → **lab 01 complete.** 🏁
Run [`../verify.md`](../verify.md).
