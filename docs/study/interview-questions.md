# Interview questions

A self-test bank, organised by topic and roughly easy → hard. **Answers are
collapsed** — try to answer out loud first, then click to check. If you can
explain the ⭐ ones cleanly, you're in good shape for a data-center design
interview.

---

## Fundamentals

??? question "What problem does VXLAN solve that VLANs cannot?"
    VLANs are limited to 4094 segments (12-bit tag) and rely on spanning tree,
    which blocks redundant links. VXLAN gives ~16M segments (24-bit VNI) and
    runs L2 over a **routed** L3 underlay, so all links are active (ECMP) and L2
    segments can stretch across a whole fabric.

??? question "⭐ In one sentence each, what do VXLAN and EVPN do?"
    **VXLAN** is the data plane — it encapsulates L2 frames in UDP/IP to carry
    them across an L3 network. **EVPN** is the control plane — a BGP address
    family that advertises where each MAC/IP lives, so tunnels are built from
    knowledge instead of flooding.

??? question "What is a VTEP?"
    VXLAN Tunnel EndPoint — the device (a leaf in spine-leaf) that encapsulates
    tenant frames into VXLAN and decapsulates them at the far end. It has tenant
    VLANs on one side and a loopback (the tunnel source) on the other.

## Underlay

??? question "What is the only job of the underlay?"
    To provide reachability between VTEP loopbacks, with equal-cost multipath.
    Nothing tenant-specific lives in the underlay.

??? question "Which protocols can run the underlay, and what's the trade-off?"
    OSPF, IS-IS, or eBGP. OSPF/IS-IS are simple IGPs, quick to stand up. eBGP
    scales better and lets one protocol (BGP) do both underlay and overlay, at
    the cost of more per-link AS/peer config. (These labs compare all of them.)

??? question "Why are /31s used on fabric links?"
    Point-to-point links only need two addresses; a /31 uses exactly two and
    wastes none, versus a /30 that wastes two per link.

??? question "⭐ Why must the underlay use jumbo MTU?"
    VXLAN adds ~50 bytes of headers. A 1500-byte tenant frame becomes ~1550 on
    the wire; a standard 1500 MTU would drop or fragment it. Fabric links run
    9000/9216 so the encapsulated packet fits.

## VXLAN data plane

??? question "Name the headers VXLAN adds and which one the spines route on."
    Outer Ethernet, Outer IP, UDP, VXLAN (VNI). The **outer IP** (source VTEP
    loopback → dest VTEP loopback) is what the underlay/spines route on — spines
    never inspect the inner frame.

??? question "What is the VXLAN UDP destination port?"
    4789 (IANA). It signals "this is VXLAN" to the receiving VTEP.

??? question "⭐ Why is the outer UDP source port important?"
    It's not a real port — the VTEP sets it to a **hash of the inner flow**. This
    gives the underlay per-flow entropy so ECMP spreads different flows across
    all spine links. It's where the load-balancing happens.

??? question "What is BUM traffic and how is it handled in EVPN-VXLAN?"
    Broadcast, Unknown-unicast, Multicast. EVPN handles it by default with
    **ingress replication** (head-end replication): the ingress VTEP unicasts a
    copy to each remote VTEP in that VNI. The replication list is built from
    **Type-3** routes. (Alternative: underlay multicast.)

??? question "Difference between an L2VNI and an L3VNI?"
    L2VNI maps to a VLAN and is used for **bridging** (same subnet across
    leaves). L3VNI is tied to a VRF and used for **routing** between subnets /
    to the outside (Type-5 routes, IRB).

## EVPN control plane

??? question "What does EVPN replace, and with what?"
    It replaces L2 flood-and-learn with BGP advertising: VTEPs announce their
    local MACs/IPs to each other instead of discovering them by flooding.

??? question "EVPN is carried in which protocol, as what?"
    MP-BGP, as an address family (AFI 25 L2VPN, SAFI 70 EVPN). In Junos:
    `family evpn signaling`.

??? question "⭐ Explain Route Distinguisher vs Route Target."
    **RD** makes each VTEP's routes unique in BGP (so two leaves advertising the
    same subnet don't collide) — typically different per VTEP. **RT** is an
    extended community controlling import/export — same RT = same virtual
    network, so it's shared across VTEPs in a VNI. **RD = uniqueness, RT =
    membership.**

??? question "What is ARP suppression and why does it help?"
    The local leaf answers ARP requests from its EVPN (Type-2) table instead of
    flooding them across the fabric. It cuts broadcast traffic and speeds up
    resolution — the ARP never leaves the ingress leaf.

??? question "iBGP vs eBGP for the overlay — when would you use each?"
    iBGP: all VTEPs one AS; simple, but needs a full mesh or route reflectors at
    scale (spines as RRs). eBGP: each leaf its own AS; scales well and lets one
    protocol do underlay + overlay, common in large fabrics. More per-peer config.

## Route types

??? question "⭐ Which EVPN route type appears first, before any host sends traffic, and why?"
    **Type-3 (Inclusive Multicast / IMET)** — advertised when a VTEP has a VNI
    with an active member. VTEPs use these to discover each other and build the
    BUM flood list; the VXLAN tunnel forms off the back of it. Type-2 only
    appears once a host is actually learned.

??? question "What does a single Type-2 route enable?"
    Remote MAC learning (install the MAC pointing at the origin VTEP's tunnel)
    **and** the IP portion feeds ARP suppression. On a host move, a new Type-2
    reconverges quickly.

??? question "When do you need a Type-5 route?"
    For routing rather than bridging — inter-subnet/inter-VNI routing via an
    L3VNI, reaching external prefixes, or summarisation. Type-5 carries an IP
    prefix with no MAC.

??? question "Which route types are involved in multihoming?"
    Type-1 (Ethernet A-D, for fast failover/aliasing) and Type-4 (Ethernet
    Segment, for Designated Forwarder election).

## Design & scale

??? question "Why spine-leaf instead of traditional three-tier?"
    Predictable any-to-any latency (every leaf is two hops from any other),
    horizontal scale (add leaves/spines), and full ECMP — no blocked links.

??? question "At scale, why not full-mesh iBGP for the overlay?"
    N leaves need N(N-1)/2 sessions — it explodes. Use spines as **route
    reflectors** (or eBGP) so each leaf peers only with the spines.

??? question "⭐ What is an anycast gateway and why use it?"
    The same gateway IP **and** MAC configured on every leaf for a subnet. A host
    always uses its local leaf as the default gateway regardless of which leaf
    it's on — so routing is optimal and VM mobility doesn't break the gateway.

??? question "Symmetric vs asymmetric IRB?"
    Both do inter-subnet routing. **Symmetric** uses a shared L3VNI and routes on
    both ingress and egress leaf (route-bridge / bridge-route symmetrical) —
    scales better and is the modern default. **Asymmetric** requires every leaf
    to have every VNI. Symmetric is generally preferred.

## Troubleshooting

??? question "The BGP-EVPN session is up but bgp.evpn.0 has 0 routes. First checks?"
    Often expected if no VNI has an active member yet. Check: is a VLAN mapped to
    a VNI? Is there an up interface in that VLAN? Is the VNI in the
    extended-vni-list? Do the RTs match between VTEPs?

??? question "Hosts can't ping across the fabric but the tunnel is up. Where do you look?"
    Check Type-2 routes exist for both hosts (`show evpn database`), MAC learned
    remotely (`show ethernet-switching table` → remote/DR flag), RT import/export
    match, correct VLAN↔VNI mapping on both leaves, and MTU on fabric links.

??? question "Ping works but large transfers fail. Likely cause?"
    MTU. Small packets fit; full-size frames + 50 bytes of VXLAN overhead exceed
    a 1500 underlay MTU. Enable jumbo frames on fabric links.

## Juniper-specific (from this lab)

??? question "⭐ On Junos, you configured a VNI but no Type-3 route appeared. Bug?"
    No — **Junos only originates the Type-3 (IMET) route once the VLAN has an
    operationally-up member interface.** With no access port in the VLAN, there's
    nothing to flood to, so nothing is advertised. Add an access port and the
    Type-3 (and tunnel) appear. (Cisco NX-OS advertises as soon as the VNI is
    defined — a real behavioural difference.)

??? question "Which single interface sources the VXLAN tunnel on a Junos leaf?"
    `lo0.0`, via `set switch-options vtep-source-interface lo0.0`. Junos uses one
    loopback for router-id, BGP peering, and VTEP source (unlike some platforms
    that use a separate VTEP loopback).

??? question "What does the `DR` flag mean in `show ethernet-switching table`?"
    Dynamic + **R**emote — a MAC learned dynamically via a **remote** VTEP over
    the VXLAN tunnel (`vtep.xxxxx`), as opposed to a locally-learned MAC on a
    physical port.

??? question "How do you read the type of an EVPN route like 3:10.0.0.21:1::10100::10.0.0.21?"
    The **leading digit** is the route type (here `3` = IMET). Then RD
    (`10.0.0.21:1`), then the VNI (`10100`), then the originator. Reading that
    first digit tells you instantly what kind of announcement it is.

---

## How to use this bank

- **First pass:** read a question, answer aloud, then reveal. Mark the ones you
  fumbled.
- **Second pass:** only the ⭐ questions — these are the ones interviewers dig
  into.
- **Tie it to the lab:** every answer here has a matching `show` command you ran
  in [lab 01](../labs.md). Seeing it live cements the theory.
