# Study first, then lab

This is the **theory track**. Read it in order *before* you touch the lab — it
builds the mental model so the lab configs mean something instead of being
commands you paste.

Each lesson is short and ends with a couple of **check-yourself questions**.
When you can answer those, move on.

## The path

| # | Lesson | You'll be able to explain… |
|---|--------|----------------------------|
| 1 | [Why VXLAN-EVPN?](01-why-vxlan-evpn.md) | What problem it solves that plain VLANs can't |
| 2 | [Underlay vs overlay](02-underlay-overlay.md) | The two-layer model everything rests on |
| 3 | [VXLAN data plane](03-vxlan-dataplane.md) | VTEP, VNI, and how a frame is encapsulated |
| 4 | [EVPN control plane](04-evpn-controlplane.md) | How VTEPs learn who's where, without flooding |
| 5 | [EVPN route types](05-route-types.md) | Type-2 / Type-3 / Type-5 and when each appears |
| 6 | [Packet walk](06-packet-walk.md) | Exactly what happens when host A pings host B |

Then → **[the Lab](../labs.md)**, where you build all of this by hand and watch
each concept appear in real `show` output.

## Also here

- **[Interview questions](interview-questions.md)** — a self-test bank organised
  by topic, from fundamentals to design and troubleshooting. Answers are
  collapsed so you can quiz yourself first.
- **[Verification cheatsheet](../concepts/verify-cheatsheet.md)** — the `show`
  commands, grouped by layer.

## One mental model to carry through everything

> **VXLAN is the tunnel. EVPN is the brain.**
> VXLAN moves L2 frames across an L3 network. EVPN is the control plane that
> tells every switch where each host lives, so those tunnels are built from
> knowledge instead of flooding.

Keep that sentence in your head. Every lesson is a detail hanging off it.
