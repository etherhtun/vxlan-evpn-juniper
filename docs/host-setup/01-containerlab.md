# Host setup 2 — Docker, containerlab, and the vJunos image

## Install Docker + containerlab
```bash
# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"    # re-login after this

# containerlab
bash -c "$(curl -sL https://get.containerlab.dev)"
containerlab version
```

## Build / load the vJunos-switch image
vJunos-switch is a VM image (`.qcow2`), wrapped into a container image with
**vrnetlab**. It is a free download from Juniper (account required).

```bash
# 1. Download vJunos-switch .qcow2 from Juniper support (do NOT commit it).
# 2. Build the container image with vrnetlab:
git clone https://github.com/hellt/vrnetlab
cp ~/vJunos-switch-23.2R1.14.qcow2 vrnetlab/juniper/vjunos-switch/
cd vrnetlab/juniper/vjunos-switch && make
docker images | grep vjunos          # note the exact tag → put it in topology.clab.yml
```

## Extra packages the scripts need
```bash
sudo apt update && sudo apt install -y sshpass tcpdump
```

> STUB — pin exact vrnetlab path/tag and any kernel-module steps after first build.
> ⚠️ Reminder: never commit the `.qcow2` or your Juniper credentials.
