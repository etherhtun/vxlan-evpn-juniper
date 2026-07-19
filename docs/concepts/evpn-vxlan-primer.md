# EVPN-VXLAN primer

Protocol-agnostic theory, written once and referenced by every lab.

## The one-paragraph mental model
**VXLAN** is the data plane: it wraps an Ethernet frame in UDP (port 4789) so
L2 can ride across an L3 fabric. **EVPN** is the control plane: a BGP address
family that tells every leaf where each MAC and host lives, so VXLAN tunnels
are built from knowledge instead of flooding. Underlay carries loopbacks;
overlay (EVPN) carries tenant reachability; VXLAN is the encapsulation between
loopbacks.

## Why build bottom-up
```
services   ← hosts, VLANs, VNIs
evpn/vxlan ← tunnels + Type-2/3 routes
overlay    ← BGP EVPN sessions
underlay   ← loopback reachability
```
Each layer depends on the one below. A tunnel cannot form until loopbacks ping;
EVPN cannot advertise until BGP is up.

> STUB — expand with diagrams (VTEP, VNI, BUM handling) as labs progress.
