# IP Addressing Plan

The canonical plan used across every lab. **If a config disagrees with this
document, this document wins — fix the config.**

The scheme is deliberately readable: from any interface IP you can tell which
device and which link it belongs to.

---

## Device IDs

Each device has a numeric ID used as the last octet of its loopback.

| Device  | ID | Role  | AS (overlay) |
|---------|----|-------|--------------|
| spine1  | 11 | spine | — (transport only) |
| spine2  | 12 | spine | — (transport only) |
| leaf1   | 21 | leaf  | 65000 |
| leaf2   | 22 | leaf  | 65000 |

Convention: spines `1X`, leaves `2X`. New leaves continue 23, 24, …

## Loopback — `lo0.0`

> **Juniper vs Cisco note:** the Cisco reference used *two* loopbacks
> (loopback0 = router-id, loopback1 = VTEP source). On Junos we use **one**
> loopback for everything — router-id, OSPF/BGP source, and VTEP source via
> `set switch-options vtep-source-interface lo0.0`. Simpler, and standard on
> Junos EVPN-VXLAN.

| Device  | lo0.0         | Used as |
|---------|---------------|---------|
| spine1  | 10.0.0.11/32  | router-id, OSPF |
| spine2  | 10.0.0.12/32  | router-id, OSPF |
| leaf1   | 10.0.0.21/32  | router-id, OSPF, BGP peer, **VTEP source** |
| leaf2   | 10.0.0.22/32  | router-id, OSPF, BGP peer, **VTEP source** |

## P2P underlay links (`/31`)

Numbering: `10.10.<link-id>.0/31`. Spine side always `.0`, leaf side `.1`.

| Link | Subnet        | Spine end        | Leaf end        |
|------|---------------|------------------|-----------------|
| 1    | 10.10.1.0/31  | spine1 (.0)      | leaf1 (.1)      |
| 2    | 10.10.2.0/31  | spine1 (.0)      | leaf2 (.1)      |
| 3    | 10.10.3.0/31  | spine2 (.0)      | leaf1 (.1)      |
| 4    | 10.10.4.0/31  | spine2 (.0)      | leaf2 (.1)      |

## Interface mapping (containerlab ↔ Junos)

> **Read this before touching a config.** In `topology.clab.yml` you cable the
> `ethN` names that containerlab presents. *Inside* vJunos those map to Junos
> interface names. Configs and `steps/` use the **Junos** names.
>
> NOTE: the exact `ethN → xe/et/ge` mapping is confirmed on first deploy with
> `show interfaces terse` and corrected here if needed.

| clab endpoint | Junos interface (expected) | Purpose |
|---------------|----------------------------|---------|
| `eth1`        | `et-0/0/0`                 | uplink to spine1 (leaves) / to leaf1 (spines) |
| `eth2`        | `et-0/0/1`                 | uplink to spine2 (leaves) / to leaf2 (spines) |
| `eth3`        | `xe-0/0/2` / `ge-0/0/2`    | host-facing access port (leaves) |
| `eth4`        | `et-0/0/3`                 | reserved (peer-link, later labs) |

## Host-facing ports (leaves only)

| Device | clab port | Connects to |
|--------|-----------|-------------|
| leaf1  | eth3      | host1       |
| leaf2  | eth3      | host2       |

## Tenant address spaces (do NOT appear in the underlay)

Carried as EVPN routes inside the fabric.

| VLAN | VNI (L2) | Subnet          | Purpose            |
|------|----------|-----------------|--------------------|
| 100  | 10100    | 10.100.10.0/24  | Tenant-A web tier  |

| Host  | IP (VLAN 100)   |
|-------|-----------------|
| host1 | 10.100.10.10/24 |
| host2 | 10.100.10.11/24 |

## VNI plan

| Type  | VNI   | Mapped to     |
|-------|-------|---------------|
| L2VNI | 10100 | VLAN 100      |
| L3VNI | 50001 | (later labs)  |

Convention: L2VNI = `10000 + VLAN`, L3VNI = `50000 + tenant index`. Makes it
obvious in `show` output whether a VNI is L2 or L3.

## Overlay design — lab 01 (iBGP full mesh)

- **All VTEPs in AS 65000.**
- **Leaves peer loopback-to-loopback with each other** (true full mesh). With
  2 leaves that is a single iBGP-EVPN session.
- **Spines run underlay OSPF only** — they forward IP packets and do NOT run
  EVPN or terminate VXLAN tunnels.

```
        spine1        spine2         ← OSPF only, no EVPN
        /    \        /    \
    leaf1 ───┼────────┼─── leaf2
        └──────iBGP-EVPN──────┘       ← single session, lo0-to-lo0
```

> Later labs introduce **spine-as-route-reflector** (spines join EVPN and
> reflect) so the fabric scales past a full mesh — that transition is its own
> lesson.
