# Labs

Each lab is a **complete, self-contained guide** — one README you read top to
bottom (overview → every step → verify → break-it). Each lab also has its **own
independent fabric** (distinct container names), so they never conflict. Guides
live on GitHub, next to the runnable topology/config/scripts.

> **Run one lab at a time** — a 2×2 vJunos fabric needs ~16 GB RAM. To switch
> labs, wipe the current one first (`./scripts/destroy.sh <lab>`).

## Lab 01 — OSPF underlay + iBGP-EVPN (full mesh) ✅

The **foundational** lab (validated on vJunos-switch 23.2R1.14). The simplest
overlay — leaves peer directly — so you see EVPN in its clearest form. Fabric:
`clab-evpn-fullmesh-*`.

👉 **[Complete guide → labs/01-ospf-ibgp/README.md](https://github.com/etherhtun/netforge-labs/blob/main/labs/01-ospf-ibgp/README.md)**

```bash
./scripts/deploy.sh 01-ospf-ibgp && ./scripts/apply.sh 01-ospf-ibgp all
```

## Lab 02 — OSPF underlay + iBGP-EVPN, spine route-reflectors ⭐ (production)

The **production** overlay: leaves peer only to the spines; spines reflect EVPN
routes (control-plane only — **not** VTEPs). Full-mesh (lab 01) doesn't scale
past a few leaves; this does. Fabric: `clab-evpn-rr-*`.

👉 **[Complete guide → labs/02-ospf-ibgp-rr/README.md](https://github.com/etherhtun/netforge-labs/blob/main/labs/02-ospf-ibgp-rr/README.md)**

```bash
./scripts/deploy.sh 02-ospf-ibgp-rr && ./scripts/apply.sh 02-ospf-ibgp-rr all
```

## Planned

| Lab | Underlay | Overlay | Status |
|-----|----------|---------|--------|
| 03  | IS-IS | iBGP-EVPN (RR) | 📋 planned |
| 04  | eBGP  | iBGP-EVPN (RR) | 📋 planned |
| 05  | eBGP  | eBGP-EVPN | 📋 planned |

Each will be a full self-contained guide like the two above.

See the [Quickstart](quickstart/intro.md) for the team workflow.
