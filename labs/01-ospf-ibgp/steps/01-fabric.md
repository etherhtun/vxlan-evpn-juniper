# Step 1 — Fabric: interfaces & loopbacks

## Concept
Before any protocol, every node needs its fabric-link IPs and a `/32` loopback.
The loopback (`lo0.0`) is the single most important address on the box — on
leaves it is the router-id, the BGP peering address, **and** the VXLAN tunnel
source. Get addressing right and everything above has a foundation.

## Config (draft — validate on live fabric)
Applied on **leaf1** (see [ipplan](../../../common/ipplan.md) for every node):
```
set interfaces et-0/0/0 unit 0 family inet address 10.10.1.1/31   # to spine1
set interfaces et-0/0/1 unit 0 family inet address 10.10.3.1/31   # to spine2
set interfaces lo0 unit 0 family inet address 10.0.0.21/32
set routing-options router-id 10.0.0.21
```
> TODO: confirm `et-0/0/x` vs `xe-/ge-` naming with `show interfaces terse`
> on first boot, then lock the mapping into ipplan.md.

## Verify
```
show interfaces terse | match "et-|lo0"     → links up, addresses present
show configuration interfaces                → matches the ipplan
```

## Checkpoint
All fabric links `up/up` and each loopback present → proceed to Step 2.
