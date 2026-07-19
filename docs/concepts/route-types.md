# EVPN route types (the ones these labs use)

| Type | Name | Carries | First appears |
|------|------|---------|---------------|
| 2 | MAC/IP advertisement | a host's MAC (and IP) behind a VTEP | when a host is learned (Step 5) |
| 3 | Inclusive Multicast (IMET) | "I have this VNI, send me BUM" | when a VNI is configured (Step 4) |
| 5 | IP Prefix | routed prefixes (inter-subnet) | later labs (L3VNI / anycast GW) |

Rule of thumb: **Type-3 = presence, Type-2 = endpoints, Type-5 = routing.**

> STUB — add Junos `show route table bgp.evpn.0` output examples after live runs.
