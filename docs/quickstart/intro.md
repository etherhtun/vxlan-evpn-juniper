# Quickstart for teams

Your team lead has set up a GCP host with containerlab and the vJunos image.
Here's how to start practicing.

---

## SSH to the host

```bash
gcloud compute ssh clab-lab --zone=asia-southeast1-b
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
git clone https://github.com/etherhtun/netforge-labs.git
cd netforge-labs
```

---

## Deploy a lab

```bash
./scripts/deploy.sh 01-ospf-ibgp
```

This boots the bare 2×2 fabric (no configs yet). **Wait 5–8 minutes** for nodes to come up.

In another terminal, watch boot progress:
```bash
docker logs -f clab-evpn-fullmesh-spine1
```

---

## Choose your path

### Path 1: Learn by hand (recommended)
Follow the lab guide and type the config yourself. This is how you actually learn.

1. Open the complete guide: [Lab 01 README](../labs/lab-01-fullmesh.md)
2. SSH into a node and apply each step's config:
   ```bash
   ssh admin@clab-evpn-fullmesh-leaf1     # password admin@123
   ```
3. Run the step's verify command, confirm the checkpoint, move to the next step

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
gcloud compute instances stop clab-lab --zone=asia-southeast1-b
```

Start it again later:
```bash
gcloud compute instances start clab-lab --zone=asia-southeast1-b
```

---

## Questions?

- **Lab concepts:** See the [Study track](../study/index.md)
- **Show command reference:** [Verification Cheatsheet](../concepts/verify-cheatsheet.md)
- **Troubleshooting:** Check the break-it exercises in each lab for failure modes
