# Labs

The labs live in the [`labs/`](https://github.com/etherhtun/vxlan-evpn-juniper/tree/main/labs)
directory of the repo — alongside their topology files, configs, and scripts, so
everything for a lab is in one place. Each lab folder has its own step-by-step
guide, verification checklist, and break-it exercises.

> Lab step content is served from GitHub for now (it sits next to the runnable
> topology/config files). Once lab 01 is validated on live hardware, these get
> pulled into the site directly.

## Lab 01 — OSPF underlay + iBGP-EVPN (full mesh) ✅

The foundational lab — **validated end-to-end on vJunos-switch 23.2R1.14.** Build
a working VXLAN-EVPN fabric from bare vJunos nodes, one layer at a time.

| Resource | Link |
|----------|------|
| Overview | [labs/01-ospf-ibgp/README.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/README.md) |
| Step 1 — Fabric | [01-fabric.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/steps/01-fabric.md) |
| Step 2 — Underlay OSPF | [02-underlay-ospf.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/steps/02-underlay-ospf.md) |
| Step 3 — Overlay iBGP | [03-overlay-ibgp.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/steps/03-overlay-ibgp.md) |
| Step 4 — EVPN + VXLAN | [04-evpn-vxlan.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/steps/04-evpn-vxlan.md) |
| Step 5 — Services | [05-services-verify.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/steps/05-services-verify.md) |
| Verify checklist | [verify.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/verify.md) |
| Break-it exercises | [break-it.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/break-it.md) |
| **Lessons from the live build** | [LESSONS.md](https://github.com/etherhtun/vxlan-evpn-juniper/blob/main/labs/01-ospf-ibgp/LESSONS.md) |

**Run it with scripts** (per-step or all at once):
```bash
./scripts/apply.sh 01-ospf-ibgp 02     # one step
./scripts/apply.sh 01-ospf-ibgp all    # all steps 01→05
```

## Planned

| Lab | Underlay | Overlay | Status |
|-----|----------|---------|--------|
| 02  | IS-IS | iBGP-EVPN | 📋 planned |
| 03  | eBGP  | iBGP-EVPN | 📋 planned |
| 04  | eBGP  | eBGP-EVPN | 📋 planned |

## Running a lab

```bash
./scripts/deploy.sh 01-ospf-ibgp    # boot the bare fabric (~5-8 min/node)
./scripts/switch.sh 01-ospf-ibgp    # push the full working config
./scripts/reset.sh  01-ospf-ibgp    # destroy + redeploy clean
```

See the [Quickstart](quickstart/intro.md) for the full team workflow.
