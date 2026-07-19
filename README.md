# VXLAN-EVPN on Juniper — Zero to Hero

A hands-on, layer-by-layer learning path for building VXLAN-EVPN fabrics on
**Juniper vJunos-switch**, run in **containerlab** on a **GCP** VM.

> Learn by building, not by pasting. Each layer is a checkpoint you *verify*
> before moving on. The fabric is built bottom-up — underlay first, then the
> overlay, then services — because that is the order in which it actually
> becomes real.

**📖 [Read the full docs](https://etherhtun.github.io/vxlan-evpn-juniper/)** —
hosted on GitHub Pages, searchable, with inline code snippets and verification
checklists.

Inspired by the Cisco-Nexus [`vxlan-evpn-zero-to-hero`](https://github.com/atr399/vxlan-evpn-zero-to-hero)
curriculum, re-built for Junos and organised around *routing-design variants*
rather than feature add-ons.

---

## The learning axis

Instead of stacking features, this repo teaches the **fabric design choices** by
swapping the underlay and overlay one at a time:

| Lab | Underlay | Overlay | Status |
|-----|----------|---------|--------|
| `01-ospf-ibgp`  | OSPF   | iBGP-EVPN (leaf-to-leaf full mesh) | 🏗️ building |
| `02-isis-ibgp`  | IS-IS  | iBGP-EVPN                          | 📋 planned |
| `03-ebgp-ibgp`  | eBGP   | iBGP-EVPN                          | 📋 planned |
| `04-ebgp-ebgp`  | eBGP   | eBGP-EVPN                          | 📋 planned |

Once the designs click, the plan is to borrow the *feature* modules
(anycast gateway, multi-VRF, ESI multihoming, multi-site) as later labs.

## Repo layout

```
common/ipplan.md        Single source of truth: IPs, ASNs, VNIs, interface map
docs/concepts/          Protocol-agnostic theory (written once, reused everywhere)
docs/host-setup/        One-time GCP + containerlab bring-up
scripts/                deploy / switch / reset / capture
labs/<NN-name>/
  topology.clab.yml     The fabric definition
  configs/*.conf        Full per-node config for that lab (the "reset button")
  steps/*.md            The layered guide you follow by hand (the learning)
  verify.md             Success checklist
  break-it.md           Deliberate-failure exercises
```

## Build order (every lab follows this)

```
lo0 reachable (ping)  →  BGP Establ  →  Type-3 + tunnel up  →  Type-2  →  host ping
     ▲                       ▲                 ▲                  ▲
  underlay               overlay            evpn/vxlan         services
```

Each arrow is a `show` command. If an arrow is broken, the fault is *at that
layer* — you never debug the whole stack at once.

## Quick start

```bash
# One-time (see docs/host-setup/):
#   1. Create a GCP VM with NESTED VIRTUALIZATION enabled
#   2. Install docker + containerlab, load the vJunos-switch image

./scripts/deploy.sh 01-ospf-ibgp       # boot the fabric (vJunos ~5-8 min/node)
# ... follow labs/01-ospf-ibgp/steps/ by hand, OR:
./scripts/switch.sh 01-ospf-ibgp       # push the full working config
./scripts/reset.sh  01-ospf-ibgp       # destroy + redeploy clean
```

## ⚠️ Do not commit

- The vJunos-switch image (`*.qcow2` / `*.tar`) — redistribution violates
  Juniper's licence. Keep it on the GCP host only.
- Any Juniper credentials, licence keys, or GCP service-account JSON.

See [`.gitignore`](.gitignore).

## Requirements

- GCP VM, Intel N1/N2/C2 family, **nested virtualization on**
- ~8 vCPU / 32 GB RAM minimum for a 2-spine × 2-leaf fabric
- containerlab + Docker
- vJunos-switch image (free from Juniper, requires an account)

## Licence

MIT — see [`LICENSE`](LICENSE).
