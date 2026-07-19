# Step 1 — Fabric: interfaces & loopbacks

## Concept
Before any protocol, every node needs its fabric-link IPs and a `/32` loopback.
The loopback (`lo0.0`) is the single most important address on the box — on
leaves it is the router-id, the BGP peering address, **and** the VXLAN tunnel
source. Get addressing right and everything above has a foundation.

## Config ✅ (validated on vJunos-switch 23.2R1.14)
Applied on **leaf1** (see [ipplan](../../../common/ipplan.md) for every node):
```
set interfaces ge-0/0/0 unit 0 family inet address 10.10.1.1/31   # to spine1
set interfaces ge-0/0/1 unit 0 family inet address 10.10.3.1/31   # to spine2
set interfaces lo0 unit 0 family inet address 10.0.0.21/32
set routing-options router-id 10.0.0.21
```
> vJunos-switch presents `ge-0/0/N` (clab `ethN` → `ge-0/0/(N-1)`). `family inet`
> commits clean on these ports — no `ethernet-switching` deletion needed.

Or just: `./scripts/apply.sh 01-ospf-ibgp 01`

## Verify
```
show interfaces terse | match "ge-|lo0"     → links up, addresses present
ping 10.10.1.0 count 3                        → leaf1 → spine1 across the /31
```
Confirmed output — the directly-connected `/31` pings before OSPF even exists:
```
64 bytes from 10.10.1.0: icmp_seq=0 ttl=64 time=5.3 ms   (0% loss)
```

## Checkpoint
All fabric links `up/up`, loopbacks present, `/31` links ping → proceed to Step 2.
