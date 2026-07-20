# Host setup 2 — Docker, containerlab, and the vJunos image

Run everything here **on the GCP VM** (after SSHing in from
[host setup 1](00-gcp-instance.md)). By the end you'll have containerlab
installed and a bootable `vJunos-switch` image that `topology.clab.yml`
references.

The one genuinely fiddly step is #4 — vJunos-switch ships as a raw VM disk that
you wrap into a container image with **vrnetlab**. Everything else is routine.

---

## 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
```
> **Log out and back in** after the `usermod` (or run `newgrp docker`) so your
> shell picks up the `docker` group — otherwise every `docker` call needs
> `sudo`. Verify:
> ```bash
> docker run --rm hello-world     # should print "Hello from Docker!"
> ```

## 2. Install containerlab

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
containerlab version
```

## 3. Extra tools the repo scripts need

```bash
sudo apt update && sudo apt install -y sshpass tcpdump make git
```
- `sshpass` — `switch.sh` uses it to push configs over SSH
- `tcpdump` — `capture.sh` uses it for `.pcap` capture
- `make` / `git` — needed to build the vJunos image next

## 4. Build the vJunos-switch image (vrnetlab)

vJunos-switch is a free download from Juniper (**account required**). It's a
`.qcow2` VM disk; vrnetlab packages it into a Docker image containerlab can run.

> ⚠️ We want **vJunos-switch** (L2 / EVPN-VXLAN switching), *not* vJunosEvolved
> (routing/PTX). Make sure you grab the switch image.

### 4a. Get the image onto the VM
Download the `.qcow2` from the Juniper support site to your laptop, then copy it
up (or download directly on the VM if you have a signed URL):
```bash
# from your laptop:
gcloud compute scp ~/Downloads/vJunos-switch-23.2R1.14.qcow2 \
    clab-lab:~/ --zone=us-central1-a
```
> 🔒 The `.qcow2` is licensed — keep it on the VM only. It's already in
> `.gitignore`; **never commit it**.

### 4b. Clone the vrnetlab fork containerlab uses
```bash
git clone https://github.com/hellt/vrnetlab.git
cd vrnetlab
```
> Use the **`hellt/vrnetlab`** fork (the one containerlab documents), not the
> upstream — it has the current Juniper build recipes.

### 4c. Drop the image in and build
On the `23.2R1` release the directory is **`vjunosswitch`** (confirmed):
```bash
cp ~/vJunos-switch-23.2R1.14.qcow2 juniper/vjunosswitch/
cd juniper/vjunosswitch
make
```
The `make` boots the VM once, bakes in defaults, and produces a Docker image.
> If your fork/version differs, list the options with `ls ~/vrnetlab/juniper*/`.

### 4d. Capture the exact image tag
```bash
docker images | grep -i vjunos
```
On `23.2R1.14` this produces exactly:
```
vrnetlab/juniper_vjunos-switch   23.2R1.14   <id>   7.27GB
```
Note the **`REPOSITORY:TAG`** (`vrnetlab/juniper_vjunos-switch:23.2R1.14`).

## 5. Point the topology at your image

**Good news:** the lab's `topology.clab.yml` already defaults to exactly this
tag — if you built `23.2R1.14`, **no edit is needed.** Confirm with:
```bash
grep image labs/01-ospf-ibgp/topology.clab.yml
# → vrnetlab/juniper_vjunos-switch:23.2R1.14
```
If your tag differs (different Junos version), edit the `image:` line to match:
```yaml
  kinds:
    juniper_vjunosswitch:                       # containerlab kind for vJunos-switch
      image: vrnetlab/juniper_vjunos-switch:23.2R1.14   # ← your tag from 4d
```
> If `containerlab deploy` later complains about an unknown kind, check
> `containerlab version` — very old versions predate the native
> `juniper_vjunosswitch` kind.

## 6. Clone the lab repo

The image build happened inside the **vrnetlab** repo. The labs live in a
**separate** repo — clone it now:
```bash
cd ~
git clone https://github.com/etherhtun/netforge-labs.git
cd netforge-labs
ls labs/                    # → 01-ospf-ibgp
```
All the `./scripts/*` and `labs/*` commands below run from **this** directory.

## 7. Smoke test

From the repo root (`~/netforge-labs`):
```bash
./scripts/deploy.sh 01-ospf-ibgp
```
First boot is slow — **~5–8 min per vJunos node**. Watch one boot:
```bash
docker logs -f clab-evpn-fullmesh-spine1
```
When it settles, list the lab and SSH into a node:
```bash
containerlab inspect -t labs/01-ospf-ibgp/topology.clab.yml
ssh admin@clab-evpn-fullmesh-spine1        # confirm creds on first login
```
> This is exactly when you resolve the repo's `NOTE/TODO` markers: the real
> login user/password, and the `ethN → et-/xe-/ge-` interface mapping
> (`show interfaces terse`). Lock both into `common/ipplan.md` once confirmed.

## 8. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `docker` needs `sudo` every time | Group not applied — log out/in, or `newgrp docker`. |
| `make` fails early / VM won't boot during build | Nested virt off on the VM — recheck `grep -cw vmx /proc/cpuinfo` (host setup 1, step 6). |
| `permission denied: /dev/kvm` | Add yourself: `sudo usermod -aG kvm "$USER"`, then re-login. |
| `unknown kind juniper_vjunosswitch` | containerlab too old — reinstall (step 2) to get the latest. |
| Nodes boot but no mgmt SSH | Wait longer (Junos mgmt comes up late), then confirm creds; adjust `LAB_USER`/`LAB_PASS` for `switch.sh`. |
| Out of disk during build | `.qcow2` + Docker layers are big — the 100 GB SSD disk from host setup 1 is sized for this. |

---

Next: back to [lab 01](https://github.com/etherhtun/netforge-labs/blob/main/labs/01-ospf-ibgp/README.md)
— deploy the bare fabric and work through the complete guide.
