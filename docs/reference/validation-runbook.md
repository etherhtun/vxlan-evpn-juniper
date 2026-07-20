# Validation Runbook (draft labs)

A structured way to validate the **draft** labs on a live vJunos fabric and report
findings. Test in the order below — later labs **inherit** earlier patterns, so
fixing the base retires most of the risk.

> Only **Lab 01** is validated so far. Labs 02–05 are drafts. One fabric at a time
> (RAM) — `destroy` before switching labs.

## How to use this
For each lab: deploy → apply → run the checks → record **PASS/FAIL** and paste any
commit error or unexpected `show` output. Send me the findings and I fix
systematically. The **⚠️ likely-fix** notes are where problems usually hide.

---

## Order & inheritance (test top-down)

| Order | Lab | Introduces | Inherited by |
|-------|-----|------------|--------------|
| 1 | **02 · RR** | spine route-reflectors | 03, 04, 05, (eBGP, L3out, MS) |
| 2 | **03 · L3VNI** | anycast IRB, L3VNI, Type-5 | 04 |
| 3 | **04 · Multi-tenancy** | 2nd VRF, route leak | — |
| 4 | **05 · ESI** | Ethernet Segment, LACP bond | — |

Validate 02 and 03 first — if those patterns are right, 04/05 are mostly
mechanical.

---

## Lab 02 — Route reflectors
```bash
./scripts/reset.sh 02-ospf-ibgp-rr && ./scripts/apply.sh 02-ospf-ibgp-rr all
```
Checks:
- [ ] leaf1 `show bgp summary` → peers to **both spines** `Establ`
- [ ] spine1 `show bgp summary` → peers to **both leaves** `Establ`
- [ ] ⭐ **spine1 `show route table bgp.evpn.0` → routes PRESENT** (RR retains/reflects)
- [ ] leaf1 `show route table bgp.evpn.0 extensive | match "Protocol next hop"` → a **leaf** loopback, not a spine
- [ ] host1 → host2 ping (after host setup) → 0% loss

⚠️ **likely-fix:** if spine's `bgp.evpn.0` is **empty**, the RR is dropping routes it
has no RT for → may need a keep-all/retain knob on the spines.

## Lab 03 — L3VNI + anycast gateway
```bash
./scripts/destroy.sh 02-ospf-ibgp-rr ; ./scripts/deploy.sh 03-l3vni-anycast && ./scripts/apply.sh 03-l3vni-anycast all
```
Checks:
- [ ] `apply.sh` commits with **no errors** on all nodes (watch for irb/routing-instance syntax)
- [ ] leaf1 `show route table TENANT.evpn.0` → **Type-5** (`5:`) route from leaf2 for `10.100.20.0/24`
- [ ] leaf1 `show route table TENANT.inet.0 10.100.20.0/24` → present, via L3VNI
- [ ] host1 (VLAN100) → host2 (VLAN200) ping → success, **ttl decrements** (routed)

⚠️ **likely-fix:** L3VNI may need adding to `switch-options extended-vni-list` (add
`50000`); `virtual-gateway-address` may need a `virtual-gateway-v4-mac`; the VRF may
need `vrf-table-label`. Paste `show evpn instance` + any commit error.

## Lab 04 — Multi-tenancy
```bash
./scripts/destroy.sh 03-l3vni-anycast ; ./scripts/deploy.sh 04-multitenancy && ./scripts/apply.sh 04-multitenancy all
```
Checks:
- [ ] Isolation: host1 (Tenant-A) → host2 (Tenant-B) ping **FAILS** (correct)
- [ ] leaf1 `show route table TENANT-A.inet.0` → only Tenant-A subnets (no `10.100.30.0/24`)
- [ ] After applying the leak policy (in the guide): ping **SUCCEEDS**, and the route appears

⚠️ **likely-fix:** `vrf-import` policy interaction with the default `vrf-target`
import — may need both, or an explicit import term for the local RT too.

## Lab 05 — ESI multihoming
```bash
./scripts/destroy.sh 04-multitenancy ; ./scripts/deploy.sh 05-esi && ./scripts/apply.sh 05-esi all
```
Checks:
- [ ] `apply.sh` commits clean (watch `ae0` / `chassis aggregated-devices`)
- [ ] host1 bond up: `docker exec clab-evpn-esi-host1 cat /proc/net/bonding/bond0 | head -5` → 802.3ad, both slaves up
- [ ] both leaves `show evpn ethernet-segment` → same ESI, `all-active`, DF elected
- [ ] host2 → host1 ping works; **fail one uplink** (`deactivate interfaces ge-0/0/2` on leaf1) → ping continues

⚠️ **likely-fix:** `ae0` needs `chassis aggregated-devices ethernet device-count ≥1`
(it's in the config — confirm it committed first); host bond mode via sysfs; DF
timing.

---

## Findings template (send me this)

```
LAB 02: PASS / FAIL
  - spine bgp.evpn.0 has routes? Y/N
  - host ping: ___
  - errors/output: ___
LAB 03: PASS / FAIL
  - Type-5 route present? Y/N
  - inter-subnet ping: ___
  - errors: ___
LAB 04: ...
LAB 05: ...
```
Paste that + any commit errors or surprising `show` output, and I'll turn the
drafts into ✅ validated labs.
