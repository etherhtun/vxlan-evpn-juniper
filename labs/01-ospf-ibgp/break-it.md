# Lab 01 — Break-it exercises

Understanding comes from watching it fail. Each exercise breaks one layer;
predict the symptom before you look, then confirm which `show` command exposes it.

1. **Kill an underlay link** — `deactivate interfaces et-0/0/0` on leaf1.
   Predict: does the loopback stay reachable? (Yes — via the other spine.)
   Where do you see the reroute? `show route 10.0.0.22`.

2. **Break BGP source** — point `local-address` at the wrong IP.
   Predict: session state? Where: `show bgp summary`.

3. **Mismatch the VNI** — set leaf2's VLAN 100 to `vni 10199`.
   Predict: does the tunnel form? Do hosts ping? Where: `show evpn database`.

4. **Remove `vtep-source-interface`** on leaf1.
   Predict: what happens to Type-3 advertisement and the tunnel?

> STUB — expand with expected symptoms + teaching notes after live validation.
