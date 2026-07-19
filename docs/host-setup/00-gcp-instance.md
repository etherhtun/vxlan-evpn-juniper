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
gcloud config set compute/zone us-central1-a
gcloud config set compute/region us-central1
```
Replace `YOUR_PROJECT_ID` with your real project ID (from the list above).

## 4. Create the VM

```bash
gcloud compute instances create clab-lab \
  --zone=us-central1-a \
  --machine-type=n2-standard-16 \
  --enable-nested-virtualization \
  --image-family=ubuntu-2404-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=100GB \
  --boot-disk-type=pd-ssd
```

What each flag does:

| Flag | Why |
|------|-----|
| `--machine-type=n2-standard-16` | 16 vCPU / 64 GB — comfortable for 2×2 vJunos (each node ~4 GB). N2 = Intel Cascade Lake, supports nested virt. |
| `--enable-nested-virtualization` | **The critical one.** Exposes VT-x to the guest so KVM works inside. |
| `--image-family=ubuntu-2404-lts` | Ubuntu 24.04 LTS — well-tested with containerlab. |
| `--boot-disk-size=100GB` `--boot-disk-type=pd-ssd` | vJunos images + Docker layers are large; SSD makes boot faster. |

> Start smaller/cheaper if you like: `n2-standard-8` (8 vCPU / 32 GB) is the
> practical minimum for 2×2. Scale up for bigger fabrics.

## 5. Connect to the VM

**SSH via gcloud (recommended — it manages keys for you):**
```bash
gcloud compute ssh clab-lab --zone=us-central1-a
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
  `clab-lab.us-central1-a.YOUR_PROJECT_ID`.

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
gcloud compute instances stop  clab-lab --zone=us-central1-a   # pause (cheap)
gcloud compute instances start clab-lab --zone=us-central1-a   # resume
gcloud compute instances delete clab-lab --zone=us-central1-a  # remove entirely
```

> ⚠️ A running containerlab fabric does **not** survive a VM stop/start — you'll
> re-run `./scripts/deploy.sh` after starting. The repo (configs, steps) lives in
> git, so nothing is lost.

---

Next: [Host setup 2 — Docker, containerlab, and the vJunos image](01-containerlab.md).
