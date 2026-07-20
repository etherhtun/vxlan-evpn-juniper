# Course 1: VXLAN-EVPN on Juniper

A structured, zero-to-hero path to VXLAN-EVPN on Juniper, **session by session**.
(A [Course 2 on Cisco](../index.md) is planned.) Each **session** follows the same
teaching rhythm:

1. **Mental model** — an analogy to anchor the idea.
2. **Why before how** — the problem this session solves, before any config.
3. **The mechanism** — the technical depth: what's actually happening on the wire
   and in the control plane.
4. **Build it** — the hands-on lab, config explained line by line.
5. **Verify** — the `show` commands, and *how to read* their output.
6. **Break & observe** — deliberately break it to see the failure mode.
7. **Lessons & interview** — gotchas and the questions an interviewer asks.

> Build order mirrors reality: **underlay → overlay → services → scale**. You
> never configure a layer until the one beneath it is verified.

## Sessions

| # | Session | You'll master | Status |
|---|---------|---------------|--------|
| 0 | [Lab platform](../host-setup/00-gcp-instance.md) | GCP + containerlab + vJunos | ✅ |
| 1 | [The underlay (OSPF)](01-underlay.md) | loopback reachability, ECMP, SPF | ✅ |
| 2 | [The overlay (iBGP-EVPN + route reflectors)](02-overlay-rr.md) | BGP-EVPN, RD/RT, RR | ✅ |
| 3 | [L2VNI — stretching a VLAN](03-l2vni.md) | bridging, Type-2/Type-3, flood lists | ✅ |
| 4 | [Anycast gateway & L3VNI](04-l3vni-anycast.md) | inter-subnet routing, Type-5, symmetric IRB | ✅ (lab draft) |
| 5 | [Multi-tenancy](05-multitenancy.md) | VRFs, route leaking, RT policy | ✅ (lab draft) |
| 6 | [ESI multihoming](06-esi-multihoming.md) | dual-homed hosts, Type-1/Type-4, DF election | ✅ (lab draft) |
| 7 | [eBGP designs](07-ebgp.md) | eBGP underlay, eBGP-EVPN overlay | ✅ teaching (lab TBD) |
| 8 | External connectivity (L3 out) | routing to the WAN, default origination | 📋 |
| 9 | Multi-site / DCI | stitching fabrics together | 📋 |

## How this relates to the other sections

- **[Study track](../study/index.md)** — shorter concept primers. Read these if
  you want the 5-minute version of a topic before the full session.
- **[Labs](../labs.md)** — the runnable fabrics (`clab-*`). Each session's
  "Build it" section drives one of these.
- **Sessions (here)** — the deep, guided course. **Start here** if you're
  learning the whole thing properly.

## Prerequisites

- A working lab host — [Session 0 / Host Setup](../host-setup/00-gcp-instance.md).
- Comfort with basic IP (addresses, subnets, routing) and the CLI. No prior EVPN
  knowledge assumed — that's what this course builds.
