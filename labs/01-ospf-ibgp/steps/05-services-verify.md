# Step 5 — Services: attach hosts & prove it end-to-end

## Concept
Put a host-facing port into VLAN 100 on each leaf, address the two containerlab
hosts in the same subnet, and generate traffic. When a host MAC is learned, a
**Type-2 (MAC/IP)** route appears in EVPN and is advertised to the far leaf —
that is the "it works" moment: the remote MAC is reachable via a VXLAN tunnel,
not a local wire.

## Config (draft — validate on live fabric)
On **leaf1** (leaf2 the same on its host port):
```
set interfaces xe-0/0/2 unit 0 family ethernet-switching interface-mode access
set interfaces xe-0/0/2 unit 0 family ethernet-switching vlan members v100
```

Host addressing (containerlab Linux hosts):
```
docker exec clab-vxlan-evpn-jnpr-host1 sh -c "ip addr add 10.100.10.10/24 dev eth1; ip link set eth1 up"
docker exec clab-vxlan-evpn-jnpr-host2 sh -c "ip addr add 10.100.10.11/24 dev eth1; ip link set eth1 up"
```

## Verify
```
show ethernet-switching table       → host2's MAC learned via the VTEP (remote)
show evpn database                   → Type-2 entries for both hosts
docker exec clab-vxlan-evpn-jnpr-host1 ping -c3 10.100.10.11    → success 🎉
```

## Checkpoint
Cross-fabric host ping succeeds → lab 01 complete. Run [`../verify.md`](../verify.md).
