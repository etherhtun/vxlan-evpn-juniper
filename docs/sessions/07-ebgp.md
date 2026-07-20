# Session 7 — eBGP Designs (eBGP underlay + eBGP-EVPN overlay)

> **Goal:** build the *same* fabric with a completely different routing design —
> **eBGP for both the underlay and the overlay**, no OSPF and no route reflectors.
> This is what many large / hyperscale fabrics run, and understanding *why* they
> choose it (and its trade-offs vs OSPF+iBGP) is core design knowledge.

*Prerequisite: Sessions 1–2 (you must understand OSPF underlay + iBGP overlay to
appreciate the alternative).*

---

## 1. Mental model

OSPF+iBGP treated the whole fabric as **one country** (one AS 65000) with an
internal directory (iBGP) that needed a central sorting office (route reflectors).

**eBGP treats every switch as its own small country.** Each has its own AS number
and peers with its neighbours at the "border" (the fabric links). There's no
central office — countries simply pass reachability along to each other, and the
**AS-path** stamped on every route prevents loops. **One protocol (BGP) runs the
roads *and* the directory.**

---

## 2. Why before how

**Why replace OSPF+iBGP that already works?**
- **One protocol, not two.** eBGP carries underlay reachability *and* the EVPN
  overlay. Fewer moving parts to operate.
- **No route reflectors.** eBGP re-advertises routes between peers by default (it
  has no iBGP split-horizon rule), so the "who reflects to whom" problem disappears.
- **Scales to hyperscale.** BGP's explicit AS-path loop prevention and policy
  control handle very large fabrics predictably. This is the Clos-fabric design in
  most hyperscaler data centers.

**What's the trade-off?**
- **More per-device config:** every switch needs an AS number and explicit peers;
  there's an AS-numbering *scheme* to design.
- A few **BGP quirks** to handle (next-hop and RT behaviour across AS — below) that
  iBGP gave you for free.

So it's a genuine design *choice*: OSPF+iBGP is simpler to stand up; eBGP is one
protocol and scales harder. Know both and when to pick each.

---

## 3. The mechanism (technical depth)

### AS-numbering scheme
A common Clos scheme: **spines share one AS**, **each leaf gets its own AS** (e.g.
spines `65100`; leaf1 `65101`, leaf2 `65102`). Private-AS range (64512–65534) or
4-byte ASNs at scale. The scheme must guarantee that a leaf's route, passing
spine→leaf, never loops back — the AS-path handles that.

### eBGP underlay
Each device advertises its **loopback** via eBGP to its directly-connected
neighbours. Because eBGP re-advertises by default, a leaf's loopback propagates
leaf→spine→other-leaf automatically — **no reflectors needed.** Two things to set:
- **ECMP:** eBGP picks one best path by default; enable **multipath** (and
  `multipath multiple-as`) so both spines are used — the ECMP we rely on for VXLAN.
- **Loop prevention vs. valid re-advertisement:** with spines sharing an AS, a
  route from leaf1 arriving at leaf2 has the spine AS once — fine. Designs where
  leaves might see their *own* AS use `as-override` / `allowas-in` carefully.

### eBGP-EVPN overlay
The overlay also runs **eBGP with `family evpn signaling`**, peering **loopback-to-
loopback** (multihop). Two quirks that iBGP hid:

- **⭐ Next-hop preservation.** eBGP normally rewrites the BGP next-hop to itself at
  each hop. For EVPN that would make the *spine* the VXLAN next-hop — wrong, the
  tunnel must stay leaf-to-leaf. So the overlay is configured to **keep the next-hop
  unchanged** for EVPN routes (the ingredient that, in iBGP, was automatic). The
  VXLAN data plane stays leaf-to-leaf; the spine only relays control.
- **Route-target across AS.** Auto-derived RTs include the AS number, so two leaves
  in *different* AS would derive *different* RTs and not import each other's routes.
  Fixes: use **manually-configured RTs** (same on all leaves) or Junos
  **`rewrite-evpn-rt-asn`** so RTs match across AS.

### The payoff is identical
Once eBGP underlay gives loopback reachability and eBGP-EVPN carries the routes with
next-hop preserved and matching RTs, **everything above (L2VNI, L3VNI, multi-tenancy)
is exactly the same** — those layers don't care how the underlay/overlay is built.
That's the whole point of the underlay/overlay separation from Session 2.

---

## 4. Build it

*(Lab 06 — eBGP — is built after the core draft labs are validated, so it inherits
confirmed EVPN/VNI config. The design is shown here.)*

**Config sketch — eBGP underlay + overlay on leaf1** (AS 65101):
```
set routing-options router-id 10.0.0.21
set routing-options autonomous-system 65101
# eBGP underlay to each spine (advertise loopback, enable ECMP)
set protocols bgp group underlay type external
set protocols bgp group underlay family inet unicast
set protocols bgp group underlay multipath multiple-as
set protocols bgp group underlay export ADVERTISE-LOOPBACK
set protocols bgp group underlay neighbor 10.10.1.0 peer-as 65100   # spine1
set protocols bgp group underlay neighbor 10.10.3.0 peer-as 65100   # spine2
# eBGP-EVPN overlay to each spine loopback (multihop, next-hop unchanged)
set protocols bgp group overlay type external
set protocols bgp group overlay multihop no-nexthop-change
set protocols bgp group overlay local-address 10.0.0.21
set protocols bgp group overlay family evpn signaling
set protocols bgp group overlay neighbor 10.0.0.11 peer-as 65100
set protocols bgp group overlay neighbor 10.0.0.12 peer-as 65100
set policy-options policy-statement ADVERTISE-LOOPBACK term 1 from interface lo0.0
set policy-options policy-statement ADVERTISE-LOOPBACK term 1 then accept
```
Spines (AS 65100) peer eBGP with every leaf on both the underlay and overlay, and
relay EVPN with next-hop unchanged. `no-nexthop-change` is the eBGP equivalent of
the RR's next-hop preservation.

---

## 5. Verify — and how to read it

**Underlay reachability with ECMP:**
```
leaf1> show route 10.0.0.22
   → via BOTH spines (multipath) — same ECMP as the OSPF underlay
```
**Overlay up and next-hop preserved:**
```
leaf1> show bgp summary                → eBGP peers to spine loopbacks, evpn family
leaf1> show route table bgp.evpn.0 extensive | match "next hop"
   → next-hop = the far LEAF (not a spine) — proves no-nexthop-change worked
```
**RTs match across AS:** if you see the peer's Type-2/3/5 routes imported into your
tables, the RT rewrite/manual-RT is correct. If tables are empty despite sessions
up, that's the RT-across-AS trap.

---

## 6. Break & observe

- **Forget `no-nexthop-change`** on the overlay → the spine becomes the VXLAN
  next-hop; tunnels form to the spine (which isn't a VTEP) and traffic breaks.
  Shows why next-hop preservation is essential.
- **Mismatched RTs across AS** (no rewrite) → BGP sessions are `Establ` but
  `bgp.evpn.0` won't import the peer's routes. The classic eBGP-EVPN gotcha.

---

## 7. Lessons & interview

- eBGP does **underlay + overlay with one protocol, no RRs** — re-advertisement is
  default, loops handled by AS-path. Scales to hyperscale; costs more per-device config.
- The two things iBGP gave free that eBGP-EVPN must configure: **next-hop
  preservation** (`no-nexthop-change`) and **matching RTs across AS**
  (`rewrite-evpn-rt-asn` / manual RTs).
- Everything above the overlay (L2VNI/L3VNI/tenancy) is **unchanged** — underlay/
  overlay separation pays off.

**Interview questions:**
1. Why does an eBGP fabric not need route reflectors?
2. In eBGP-EVPN, why must you preserve the BGP next-hop, and what breaks if you don't?
3. Two leaves in different AS have EVPN sessions up but import none of each other's
   routes. What's wrong?
4. How do you get ECMP across both spines in an eBGP underlay?
5. When would you choose eBGP over OSPF+iBGP for a fabric, and vice-versa?

---

**Next:** Session 8 — **External connectivity (L3 out)** — getting tenant traffic
in and out of the fabric to the WAN/internet.
