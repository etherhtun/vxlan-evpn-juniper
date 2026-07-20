# Session 3 — L2VNI: Stretching a VLAN Across the Fabric

> **Goal:** put real hosts on the wire and make two of them, on *different leaves*,
> behave as if they share one Ethernet segment. This is where the overlay stops
> being plumbing and starts carrying tenant traffic. You'll watch the exact EVPN
> routes appear — Type-3 first, then Type-2 — and see a ping cross the fabric
> inside a VXLAN tunnel.

*Prerequisite: the underlay (Session 1) and overlay (Session 2) are up.*

---

## 1. Mental model

A **VLAN** is a room — one broadcast domain where everyone hears everyone.
Normally a room exists inside one building (one switch). An **L2VNI stretches that
room across buildings**: host1 in building A and host2 in building B are in the
*same room*, even though a routed network sits between the buildings.

The **VNI** is the room number written on every piece of mail, so each building
knows which stretched room a frame belongs to. VXLAN is the envelope that carries
the frame between buildings; EVPN is the directory that says which building each
resident lives in.

---

## 2. Why before how

**Why stretch Layer-2 at all?**
Because workloads expect it. A VM keeps its IP when it moves; clustering and
failover protocols assume same-subnet adjacency; some appliances only work on a
flat segment. The data center needs "same subnet, anywhere in the fabric" — that's
exactly an L2VNI.

**Why not just one big VLAN everywhere (classic L2)?**
That's back to spanning tree, blocked links, and one giant failure domain
(Session 1). The L2VNI gives you the *stretched-segment behaviour* tenants want,
while the fabric underneath stays fully-routed and loop-free.

**Why does EVPN make this better than plain VXLAN?**
Plain VXLAN would flood to learn MACs. EVPN **advertises** them (Type-2), so the
fabric learns hosts from BGP updates, floods far less, and can even answer ARP
locally (ARP suppression). Control-plane learning instead of data-plane flooding.

---

## 3. The mechanism (technical depth)

### The VLAN-to-VNI mapping and the VTEP
On each leaf you map a VLAN to a VNI and tell the switch to source VXLAN tunnels
from its loopback:
- `vlans v100 vxlan vni 10100` — VLAN 100 is carried in the fabric as VNI 10100.
- `switch-options vtep-source-interface lo0.0` — tunnels originate from `lo0.0`.
- `route-distinguisher` (unique per leaf) + `vrf-target` (shared per VNI) — the
  RD/RT from Session 2 that make routes unique and controllable.

### Type-3 (IMET) — *"I have this VNI"*
The moment a leaf has an **active** member in the VLAN, it originates a **Type-3
(Inclusive Multicast) route**: *"I participate in VNI 10100 — put me on the flood
list for it."* Every VTEP collects these to know **who to replicate broadcast /
unknown-unicast / multicast (BUM) traffic to** — this is **ingress replication**
(the ingress leaf unicasts a copy to each remote VTEP in the VNI). Type-3 is also
what triggers the VXLAN tunnel to form between the leaf loopbacks.

> ⭐ **Junos-specific behaviour you must know.** Junos originates the Type-3 route
> **only once the VLAN has an operationally-up member interface** — i.e. after you
> add a host-facing access port. Configure the VNI with no ports and
> `show route table bgp.evpn.0` stays *empty* — that's not a bug. (Cisco NX-OS
> advertises as soon as the VNI is defined; this vendor difference is a classic
> gotcha, and a great interview question.)

### Type-2 (MAC/IP) — *"this exact host is behind me"*
When a leaf learns a local host (from a frame, ARP, or DHCP) it originates a
**Type-2 route** carrying that host's **MAC** (and often its **IP**): *"aa:bb:cc /
10.100.10.11 lives behind VTEP 10.0.0.22 in VNI 10100."* Remote leaves install
that MAC pointing at the origin leaf's tunnel. The IP portion also enables **ARP
suppression** — a leaf can answer an ARP request locally from its EVPN table
instead of flooding it across the fabric.

### Putting it together — the packet walk
1. Access ports come up → each leaf sends its **Type-3** → tunnels form, flood
   lists built.
2. host1 ARPs for host2 → leaf1 floods it (ingress replication) to leaf2 → host2
   answers. Meanwhile each leaf learns its local host and sends a **Type-2**.
3. Now both leaves know both hosts. host1→host2 traffic is **unicast VXLAN**:
   leaf1 wraps the frame (VNI 10100, dst = leaf2's loopback), the underlay routes
   it (Session 1's ECMP), leaf2 unwraps and delivers. No more flooding.

---

## 4. Build it

This session is **steps 04–05** of either lab (they share the same L2VNI). Using
the full-mesh lab:

```bash
./scripts/apply.sh 01-ospf-ibgp 04     # EVPN + VXLAN glue (VNI 10100)
./scripts/apply.sh 01-ospf-ibgp 05     # access ports (this is what lights it up)
```

**Config, explained — leaf1** (leaf2 mirrors with RD `10.0.0.22:1`):
```
set protocols evpn encapsulation vxlan             # EVPN uses VXLAN encap
set protocols evpn extended-vni-list all           # handle all configured VNIs
set switch-options vtep-source-interface lo0.0     # tunnels sourced from loopback
set switch-options route-distinguisher 10.0.0.21:1 # unique per leaf
set switch-options vrf-target target:65000:1       # shared per VNI (membership)
set vlans v100 vlan-id 100                          # the VLAN
set vlans v100 vxlan vni 10100                      # mapped to VNI 10100
```
Then the host-facing access port (Step 5) — **this is what makes Type-3 appear:**
```
set interfaces ge-0/0/2 unit 0 family ethernet-switching interface-mode access
set interfaces ge-0/0/2 unit 0 family ethernet-switching vlan members v100
```
Full walkthrough incl. host IPs: **[Lab 01 guide](../labs/lab-01-fullmesh.md)**.

---

## 5. Verify — and how to read it

### Type-3 appears the instant the access port is up
```
leaf1> show route table bgp.evpn.0
3:10.0.0.21:1::10100::10.0.0.21/248 IM   ← my own Type-3
3:10.0.0.22:1::10100::10.0.0.22/248 IM   ← from leaf2
```
The leading `3:` = Type-3 (IMET); `10100` = the VNI. Two of them = both VTEPs are
on the flood list for VNI 10100. The tunnel is up:
```
leaf1> show ethernet-switching vxlan-tunnel-end-point remote
   RVTEP-IP 10.0.0.22  ...  vtep.32769  VNID 10100
```

### Type-2 appears once hosts talk
```
leaf1> show evpn database
  10100  aa:c1:ab:cf:00:a6  10.0.0.22    10.100.10.11   ← host2 via leaf2's VTEP (remote)
  10100  aa:c1:ab:e9:b3:87  ge-0/0/2.0   10.100.10.10   ← host1 (local)
```
One local, one remote — each carrying MAC **and** IP (the full Type-2). And in the
switching table:
```
leaf1> show ethernet-switching table
  v100  aa:c1:ab:cf:00:a6  DR  vtep.32769   ← DR = Dynamic Remote (lives on the tunnel)
```
The `DR` flag is the proof: host2's MAC is reachable over a **VXLAN tunnel**, not a
local wire.

### The payoff
```
host1$ ping -c3 10.100.10.11        → 0% loss, across the fabric 🎉
```

---

## 6. Break & observe

**Mismatch the VNI:**
```
leaf2# set vlans v100 vxlan vni 10199   ; commit
```
- **Predict:** do the hosts still ping?
- **Observe:** the leaves now disagree on the VNI for VLAN 100 — the L2 stretch
  breaks; `show evpn database` no longer lines up. Restore `10100`.

**Remove the VTEP source:**
```
leaf1# delete switch-options vtep-source-interface   ; commit
```
- **Observe:** leaf1 can no longer source VXLAN — its Type-3 withdraws and the
  tunnel drops (`show ethernet-switching vxlan-tunnel-end-point remote`). Restore
  `lo0.0`.

---

## 7. Lessons & interview

**Gotchas (validated live):**
- **Type-3 needs an up member** on Junos — the tunnel/routes appear at the
  access-port step, not when the VNI is first defined.
- Remote MACs show the **`DR`** flag via `vtep.xxxxx`; local MACs show on the
  physical port.

**Interview questions:**
1. Which EVPN route type appears first, before any host sends traffic — and why?
2. What does a single Type-2 route carry, and what two things does it enable?
3. How is BUM traffic delivered across the fabric with EVPN (no multicast underlay)?
4. On Junos you defined a VNI but `bgp.evpn.0` is empty. Bug or expected — and what
   makes the routes appear?
5. What is ARP suppression and why does it reduce fabric flooding?

---

**Next:** Session 4 — **L3VNI & the anycast gateway** — where we add a *second*
subnet and route *between* subnets across the fabric (Type-5 routes, symmetric
IRB), so hosts in different VLANs can reach each other.
