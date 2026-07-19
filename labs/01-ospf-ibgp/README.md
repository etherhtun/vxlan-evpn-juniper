# Lab 01 — OSPF underlay + iBGP-EVPN (full mesh)

The foundational lab. Build a working VXLAN-EVPN fabric from bare vJunos nodes,
one layer at a time, verifying at every step.

## Design

| Layer    | Choice |
|----------|--------|
| Underlay | OSPF (single area 0) |
| Overlay  | iBGP-EVPN, AS 65000, **leaf-to-leaf full mesh** |
| Spines   | underlay transport only — no EVPN, no VTEP |
| Services | one L2VNI (VLAN 100 → VNI 10100), two hosts same subnet |

See [`../../common/ipplan.md`](../../common/ipplan.md) for all addresses.

## Physical topology

2 spine × 2 leaf, full-mesh fabric. Each leaf dual-homes to both spines over
`/31` links; one host hangs off each leaf in VLAN 100.

```mermaid
graph TB
    S1["spine1<br/>lo0 10.0.0.11"]
    S2["spine2<br/>lo0 10.0.0.12"]
    L1["leaf1 · VTEP<br/>lo0 10.0.0.21"]
    L2["leaf2 · VTEP<br/>lo0 10.0.0.22"]
    H1["host1<br/>10.100.10.10/24"]
    H2["host2<br/>10.100.10.11/24"]

    S1 ---|"10.10.1.0/31"| L1
    S1 ---|"10.10.2.0/31"| L2
    S2 ---|"10.10.3.0/31"| L1
    S2 ---|"10.10.4.0/31"| L2
    L1 ---|"VLAN 100"| H1
    L2 ---|"VLAN 100"| H2

    classDef spine fill:#e3f2fd,stroke:#1565c0,color:#0d47a1;
    classDef leaf  fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20;
    classDef host  fill:#fff3e0,stroke:#ef6c00,color:#e65100;
    class S1,S2 spine;
    class L1,L2 leaf;
    class H1,H2 host;
```

## How the layers stack

Each step adds one layer on top of the last. The diagram on the right of each
step shows what that layer introduces.

```mermaid
graph LR
    A["Step 1<br/>Fabric<br/>interfaces + lo0"]
      --> B["Step 2<br/>Underlay OSPF<br/>lo0 reachable"]
      --> C["Step 3<br/>Overlay iBGP<br/>EVPN session"]
      --> D["Step 4<br/>EVPN + VXLAN<br/>tunnel + Type-3"]
      --> E["Step 5<br/>Services<br/>host ↔ host"]
```

## The build (follow `steps/` in order)

| Step | File | Verifies before you continue |
|------|------|------------------------------|
| 1 | [steps/01-fabric.md](steps/01-fabric.md)          | interfaces up, loopbacks present |
| 2 | [steps/02-underlay-ospf.md](steps/02-underlay-ospf.md) | `lo0` ping leaf-to-leaf |
| 3 | [steps/03-overlay-ibgp.md](steps/03-overlay-ibgp.md)   | BGP EVPN session `Established` |
| 4 | [steps/04-evpn-vxlan.md](steps/04-evpn-vxlan.md)       | Type-3 route + VXLAN tunnel up |
| 5 | [steps/05-services-verify.md](steps/05-services-verify.md) | host1 ↔ host2 across the fabric |

Then: [`verify.md`](verify.md) (full checklist) and
[`break-it.md`](break-it.md) (deliberate failures).

## Two ways to run it

```bash
# Learning path — bare fabric, type each layer yourself:
./scripts/deploy.sh 01-ospf-ibgp
#   ... then work through steps/01 → 05

# Reset button — push the full working config at once:
./scripts/switch.sh 01-ospf-ibgp
```

> `configs/*.conf` (the full working configs) and `steps/*.md` (the by-hand
> layers) describe the **same** end state — stacking the steps equals the
> config file.

## Status

🏗️ Scaffold in place. Step content + configs are stubs — filled in one layer
at a time, each validated on a live fabric before the next is written.
