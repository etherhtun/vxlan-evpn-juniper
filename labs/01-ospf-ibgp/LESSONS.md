# Lessons from the live build — Lab 01

Validated on **vJunos-switch 23.2R1.14** in containerlab on GCP, 2026-07-19.
These are the things the real hardware taught us that a paper design misses.

## 1. Interfaces are `ge-0/0/N`, with a +1 offset

vJunos-switch presents **`ge-0/0/0`, `ge-0/0/1`, …** (not `et-`/`xe-`). The
containerlab wiring maps with an offset:

| clab `ethN` | Junos |
|-------------|-------|
| eth1 | ge-0/0/0 |
| eth2 | ge-0/0/1 |
| eth3 | ge-0/0/2 |

The `ge-0/0/N.16386` sub-units in `show interfaces terse` are internal — ignore.

## 2. `family inet` commits clean on `ge-` ports

We expected to have to delete a default `family ethernet-switching` first. Not
so — these clab vJunos ports come up unconfigured, so routed `/31` underlay
config applies directly. (Access ports get `family ethernet-switching` in Step 5.)

## 3. Credentials: `admin` / `admin@123`

The containerlab default for `juniper_vjunosswitch`. Matches the scripts'
`LAB_USER`/`LAB_PASS` defaults.

## 4. Junos originates Type-3 only when the VLAN has an up member ⭐

**The biggest surprise, and the most important lesson.** After configuring the
VNI (Step 4), `bgp.evpn.0` was *empty* — no Type-3 (IMET) route. That is *not* a
bug:

- **Cisco NX-OS**: advertises the VNI as soon as it's defined.
- **Junos**: only originates the IMET route once the VLAN has an
  operationally-up member interface.

So the tunnel and Type-3 appear in **Step 5** (access port up), not Step 4. If
you're staring at an empty `bgp.evpn.0`, add an access port before assuming
something's broken.

## 5. Management subnet overlaps the loopbacks (but is isolated)

`fxp0` sits on **10.0.0.0/24**, overlapping our loopback plan (10.0.0.11/.12/
.21/.22). They're in separate routing instances (`mgmt_junos.inet.0` vs
`inet.0`), so it works — but it's a smell. A future cleanup could move loopbacks
to `10.255.0.X/32`.

## 6. Benign warnings on an eval image

`License key missing; requires 'bgp'/'vxlan' license` appears in output. vJunos
is an evaluation image — it warns but runs every feature fully. Ignore for labs.

## 7. "OSPF instance is not running" is usually just timing

Seen right after commit — the adjacency hadn't formed yet. Wait ~30s and
re-check `show ospf neighbor` before diagnosing deeper.

---

### The clean result, for reference
```
Underlay:  leaf1 → leaf2 loopback ping, ttl=63 (one spine hop)
Overlay:   bgp.evpn.0 peer 10.0.0.22 Establ
Type-3:    3:10.0.0.21:1::10100  +  3:10.0.0.22:1::10100  (IMET, both VTEPs)
Tunnel:    RVTEP 10.0.0.21 via vtep.32769, VNID 10100
Type-2:    host MACs learned, remote one flagged DR (Dynamic Remote)
Data:      host1 → host2 ping, 0% loss across VXLAN
```
