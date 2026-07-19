# Junos EVPN-VXLAN verification cheatsheet

The `show` commands reused across every lab, grouped by layer.

## Underlay
```
show ospf neighbor
show route <loopback>
ping <remote-lo> source <local-lo>
```

## Overlay (BGP)
```
show bgp summary
show bgp neighbor <peer>
```

## EVPN / VXLAN
```
show evpn database
show route table bgp.evpn.0
show ethernet-switching vxlan-tunnel-end-point remote
```

## Data plane
```
show ethernet-switching table
show interfaces terse
```

## Config inspection
```
show configuration | display set
show configuration | display set | match <string>
```

> STUB — annotate each with "what good output looks like" after first validation.
