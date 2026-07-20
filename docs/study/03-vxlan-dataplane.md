# 3 — VXLAN data plane

This lesson is about the **packet on the wire** — how a tenant frame physically
crosses the fabric. (The next lesson is the *control plane* — how VTEPs know
where to send it.)

## Three terms

| Term | Meaning |
|------|---------|
| **VTEP** | VXLAN Tunnel EndPoint — the leaf that wraps/unwraps VXLAN (see lesson 2) |
| **VNI** | VXLAN Network Identifier — the 24-bit segment ID (~16M values) |
| **VXLAN tunnel** | The logical VTEP-to-VTEP path a wrapped frame travels |

### L2VNI vs L3VNI
- **L2VNI** — maps to a VLAN; used for **bridging** (same subnet across leaves).
  Lab 01 uses one L2VNI: VLAN 100 → VNI 10100.
- **L3VNI** — associated with a VRF; used for **routing** between subnets
  (inter-VNI / to the outside). Comes in later labs.

## Encapsulation — the "shipping box"

When host1's frame reaches leaf1, leaf1 wraps it in four new headers:

```
┌────────────────────────────────────────────────────────────┐
│ Outer Ethernet │ Outer IP │ UDP │ VXLAN │  ORIGINAL FRAME   │
│  leaf→leaf MAC  │ VTEP→VTEP│ 4789│  VNI  │ (host1→host2 eth) │
└────────────────────────────────────────────────────────────┘
        14 B          20 B     8 B    8 B      the tenant's frame
```

- **Outer IP** = source leaf1's loopback → dest leaf2's loopback. This is what the
  underlay routes on. The spines only ever look at *this*.
- **UDP, destination port 4789** = the IANA VXLAN port. It's how a receiver knows
  "this is VXLAN, decapsulate it."
- **VXLAN header** = carries the **VNI** (which segment this frame belongs to).
- **Original frame** = the tenant's untouched Ethernet frame (host1 → host2).

This is called **MAC-in-UDP**: a whole L2 frame carried as the payload of a UDP
packet.

## Why UDP? (a favourite interview question)

The outer **UDP source port is not a real port** — the VTEP computes it as a
*hash of the inner flow*. That gives the underlay per-flow **entropy** so ECMP
can spread different flows across all the spine links. The destination port is
fixed (4789); the source port is where the load-balancing magic lives.

## BUM traffic — broadcast, unknown-unicast, multicast

Unicast is easy (send to the one VTEP that owns the MAC). But what about a
broadcast (like ARP) when the VTEP doesn't yet know the destination?

Two ways to flood BUM across the fabric:

1. **Ingress replication (head-end replication)** — the ingress VTEP makes a
   copy for **each** remote VTEP that has that VNI, and unicasts each. No
   multicast needed in the underlay. **This is what EVPN uses by default**, and
   the list of "who has this VNI" comes from **Type-3 routes** (next lesson).
2. **Underlay multicast** — map the VNI to a multicast group. Scales better for
   huge fabrics but needs multicast in the underlay. Less common in labs.

## MTU — the gotcha

Those extra headers add **50 bytes** (54 with a VLAN tag). If the tenant sends a
1500-byte frame, the wrapped packet is 1550 — which a standard 1500-MTU underlay
would drop or fragment. So **fabric links run jumbo MTU (9000/9216)**. Forgetting
this is a classic "it works for ping but breaks for real traffic" bug.

## Check yourself

1. Name the four headers VXLAN adds, and which one the spines route on.
2. What's special about the outer UDP **source** port, and why does it matter?
3. What are the two ways to handle BUM traffic, and which does EVPN use by default?
4. Why must fabric links use jumbo MTU?

→ Next: [EVPN control plane](04-evpn-controlplane.md)
