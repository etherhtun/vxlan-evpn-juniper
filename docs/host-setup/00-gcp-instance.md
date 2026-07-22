# Host setup 1 — GCP instance with nested virtualization

vJunos-switch runs as a full VM (KVM) *inside* the containerlab container. So
the GCP VM must itself allow **nested virtualization** — a VM running VMs. This
is the single most important host detail; get it wrong and the nodes never boot.

```
GCP VM (KVM guest)  →  containerlab container  →  vJunos VM (needs KVM again)
        └────────── nested virtualization must be ON ──────────┘
```

---

## 1. Prerequisites

- A **Google Cloud account** with billing enabled and a **project**.
- The `gcloud` CLI on your laptop, **or** use the in-browser **Cloud Shell**
  (no install — it has `gcloud` built in). Both work; pick one below.

> 💡 If your project is under an organization, nested virt can be blocked by the
> org policy `constraints/compute.disableNestedVirtualization`. If VM creation
> is rejected for that reason, see [Troubleshooting](#7-troubleshooting).

## 2. Get a shell with `gcloud`

**Option A — Cloud Shell (easiest, nothing to install):**
Open <https://console.cloud.google.com>, click the **`>_`** terminal icon
(top-right). You're now authenticated as your Google account.

**Option B — gcloud CLI on your Mac:**
```bash
# Install (Homebrew)
brew install --cask google-cloud-sdk

# Log in — opens a browser to authenticate
gcloud auth login
```

## 3. Point gcloud at your project + region

```bash
# List projects if you're not sure of the ID
gcloud projects list

# Set the active project and sensible defaults (so you can omit them later)
gcloud config set project YOUR_PROJECT_ID
gcloud config set compute/zone asia-southeast1-b
gcloud config set compute/region asia-southeast1
```
Replace `YOUR_PROJECT_ID` with your real project ID (from the list above).

## 4. Create the VM

```bash
gcloud compute instances create clab-lab \
  --zone=asia-southeast1-b \
  --machine-type=n2-standard-16 \
  --enable-nested-virtualization \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=100GB \
  --boot-disk-type=pd-ssd
```

> ⚠️ **Image family naming:** Ubuntu 24.04's family carries an arch suffix —
> `ubuntu-2404-lts-amd64`, **not** `ubuntu-2404-lts` (the latter errors with
> *"resource … not found"*). Confirm the exact name anytime with:
> ```bash
> gcloud compute images list --project=ubuntu-os-cloud --filter="family~ubuntu-2404"
> ```
> The older `ubuntu-2204-lts` (no suffix) also works fine for containerlab.

What each flag does:

| Flag | Why |
|------|-----|
| `--machine-type=n2-standard-16` | 16 vCPU / 64 GB — comfortable for 2×2 vJunos (each node ~4 GB). N2 = Intel Cascade Lake, supports nested virt. |
| `--enable-nested-virtualization` | **The critical one.** Exposes VT-x to the guest so KVM works inside. |
| `--image-family=ubuntu-2404-lts-amd64` | Ubuntu 24.04 LTS — well-tested with containerlab. (Note the `-amd64` suffix — see warning below.) |
| `--boot-disk-size=100GB` `--boot-disk-type=pd-ssd` | vJunos images + Docker layers are large; SSD makes boot faster. |

> Start smaller/cheaper if you like: `n2-standard-8` (8 vCPU / 32 GB) is the
> practical minimum for 2×2. Scale up for bigger fabrics.

## 5. Connect to the VM

**SSH via gcloud (recommended — it manages keys for you):**
```bash
gcloud compute ssh clab-lab --zone=asia-southeast1-b
```
First run generates an SSH key and pushes it to the instance automatically.
You'll land at an Ubuntu shell on the VM — this is where you run the
[containerlab setup](01-containerlab.md) and all `./scripts/*` commands.

**Alternatives:**
- **Browser SSH** — in the Console, VM instances list → click **SSH** next to
  `clab-lab`. Zero setup.
- **VS Code Remote-SSH** — nice for editing configs and *downloading `.pcap`
  files* (see `scripts/capture.sh`). Add a `~/.ssh/config` host; the easiest way
  to get the exact connection details is:
  ```bash
  gcloud compute config-ssh          # writes host entries to ~/.ssh/config
  ```
  Then in VS Code: **Remote-SSH: Connect to Host…** → pick
  `clab-lab.asia-southeast1-b.YOUR_PROJECT_ID`.

## 6. Verify nested virtualization is really on

Run this **on the VM** (after SSHing in):
```bash
grep -cw vmx /proc/cpuinfo     # > 0  → Intel VT-x is exposed to the guest ✅
```
`0` means nested virt is **off** — the instance was created without the flag or
an org policy stripped it. Fix that before installing containerlab; otherwise
vJunos nodes will hang at boot.

Optional deeper check once KVM tools are installed:
```bash
sudo apt install -y cpu-checker && sudo kvm-ok
# expect: "KVM acceleration can be used"
```

## 7. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `create` fails: *nested virtualization disabled by policy* | Org policy `constraints/compute.disableNestedVirtualization` is enforced. An org admin must set it to *not enforced* on the project. |
| `grep vmx /proc/cpuinfo` returns 0 | Instance created without `--enable-nested-virtualization`, or on an unsupported machine type. Recreate on an N1/N2/C2 type with the flag. |
| `Quota 'CPUS' exceeded` | Request a CPU quota increase for the region, or pick a smaller machine type / different region. |
| vJunos nodes stuck booting | Almost always nested virt off (step 6), or too little RAM. |

## 8. Cost management — don't leave it running

A 16-vCPU VM bills by the second while **running**. Stop it when you're done for
the day (you keep the disk + configs, pay only for storage):

```bash
gcloud compute instances stop  clab-lab --zone=asia-southeast1-b   # pause (cheap)
gcloud compute instances start clab-lab --zone=asia-southeast1-b   # resume
gcloud compute instances delete clab-lab --zone=asia-southeast1-b  # remove entirely
```

> ⚠️ A running containerlab fabric does **not** survive a VM stop/start — you'll
> re-run `./scripts/deploy.sh` after starting. The repo (configs, steps) lives in
> git, so nothing is lost.

## 9. Moving the VM to another region

If a zone runs out of capacity for your machine type (`VM instance is currently
unavailable in the … zone` — common with larger types), recreate the VM elsewhere
via a **machine image**. This preserves everything on the disk — the built vJunos
image, the repo, and configs — so you **don't re-download or rebuild the Juniper
OS**:

```bash
# 1. capture the (stopped) VM as a machine image
gcloud compute machine-images create clab-lab-img \
  --source-instance=clab-lab --source-instance-zone=<old-zone>

# 2. recreate in the new zone, keeping nested virtualization
gcloud compute instances create clab-lab \
  --zone=asia-southeast1-b \
  --source-machine-image=clab-lab-img \
  --machine-type=n2-standard-8 \
  --enable-nested-virtualization

# 3. verify it's good, then delete the old VM + image (stop double-billing)
gcloud compute instances delete clab-lab --zone=<old-zone>
gcloud compute machine-images delete clab-lab-img
```
The Juniper OS travels with the disk — confirm on the new VM with
`docker images | grep vjunos` and `grep -cw vmx /proc/cpuinfo` (nested virt on).

---

Next: [Host setup 2 — Docker, containerlab, and the vJunos image](01-containerlab.md).
