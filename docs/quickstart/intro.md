# Quickstart for teams

Your team lead has set up a GCP host with containerlab and the vJunos image.
Here's how to start practicing.

---

## SSH to the host

```bash
gcloud compute ssh clab-lab --zone=us-central1-a
```
(Adjust the zone if your host is elsewhere.)

You should land at an Ubuntu shell. Verify containerlab is installed:
```bash
containerlab version
docker images | grep -i vjunos
```

---

## Clone the lab repo

```bash
git clone https://github.com/etherhtun/vxlan-evpn-juniper.git
cd vxlan-evpn-juniper
```

---

## Deploy a lab

```bash
./scripts/deploy.sh 01-ospf-ibgp
```

This boots the bare 2×2 fabric (no configs yet). **Wait 5–8 minutes** for nodes to come up.

In another terminal, watch boot progress:
```bash
docker logs -f clab-vxlan-evpn-jnpr-spine1
```

---

## Choose your path

### Path 1: Learn by hand (recommended)
Follow the lab steps and type the config yourself. This is how you actually learn.

1. Read [Lab 01 Step 1 — Fabric](../../labs/01-ospf-ibgp/steps/01-fabric.md)
2. SSH into a node and apply the config:
   ```bash
   ssh admin@clab-vxlan-evpn-jnpr-leaf1
   ```
3. Run the verify commands from the step
4. Move to the next step

### Path 2: Push the full config at once
Skip the hand-typing and deploy the working config:
```bash
./scripts/switch.sh 01-ospf-ibgp
```

Then inspect the running fabric and do the break-it exercises to learn failure modes.

---

## Capture packet traces (optional)

```bash
./scripts/capture.sh leaf1 eth1 01-underlay-ospf 'ospf'
```

This saves a `.pcap` in `labs/01-ospf-ibgp/pcaps/`. Download it to your laptop and
open in Wireshark.

---

## Reset or start over

```bash
./scripts/reset.sh 01-ospf-ibgp    # destroy and redeploy the topology
```

---

## When you're done

Stop the GCP host to save cost (lab data persists):
```bash
# on your laptop:
gcloud compute instances stop clab-lab --zone=us-central1-a
```

Start it again later:
```bash
gcloud compute instances start clab-lab --zone=us-central1-a
```

---

## Questions?

- **Lab concepts:** See [Concepts — EVPN-VXLAN Primer](../concepts/evpn-vxlan-primer.md)
- **Show command reference:** [Verification Cheatsheet](../concepts/verify-cheatsheet.md)
- **Troubleshooting:** Check the break-it exercises in each lab for failure modes
