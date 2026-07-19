# Host setup 1 — GCP instance with nested virtualization

vJunos-switch runs as a VM *inside* the containerlab container, so the GCP VM
must itself allow nested KVM. This is the single most important host detail.

## Requirements
- Intel platform that supports nested virt: **N1, N2, or C2** family
  (NOT T2D/N2D AMD for nested KVM).
- Enough headroom: a 2-spine × 2-leaf fabric ≈ **8 vCPU / 32 GB RAM** minimum.
- Nested virtualization **enabled** on the instance.

## Create the VM (draft)
```bash
# TODO: fill project/zone; confirm image + machine type on first run.
gcloud compute instances create clab-lab \
  --zone=us-central1-a \
  --machine-type=n2-standard-16 \
  --enable-nested-virtualization \
  --image-family=ubuntu-2404-lts --image-project=ubuntu-os-cloud \
  --boot-disk-size=100GB
```

## Verify nested virt is on
```bash
grep -cw vmx /proc/cpuinfo     # > 0 means Intel VT-x is exposed to the guest
```

> STUB — expand with firewall rules, SSH/VS Code access, and disk sizing.
