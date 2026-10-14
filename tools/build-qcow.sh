#!/usr/bin/env bash
# Turn localhost/foxhoundos:dev into output/qcow2/disk.qcow2 with
# bootc-image-builder. Runs inside the privileged `builder` service (via
# `just qcow`); bootc-image-builder itself needs --privileged to set up loop
# devices and mount the filesystems it writes.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=tools/lib/cgroups.sh
source tools/lib/cgroups.sh

IMAGE=localhost/foxhoundos:dev
# Pin by digest once a build is known good.
BIB_IMAGE=quay.io/centos-bootc/bootc-image-builder:latest

if ! podman image exists "${IMAGE}"; then
  echo "error: ${IMAGE} not found; run 'just image' first" >&2
  exit 1
fi

# bootc-image-builder runs a recent podman internally, which refuses to work
# on cgroups v1. Docker Desktop's WSL2 VM can still be on v1; fail early with
# the fix instead of bib's misleading "make sure to pull" message.
if [[ "$(stat -fc %T /sys/fs/cgroup)" != "cgroup2fs" ]]; then
  cat >&2 <<'MSG'
error: Docker is running with cgroups v1; bootc-image-builder needs cgroups v2.

On Windows (Docker Desktop + WSL2), in PowerShell:
  1. wsl --update
  2. Add these lines to %UserProfile%\.wslconfig (create the file if needed;
     if it already has a [wsl2] section, add only the second line under it):
       [wsl2]
       kernelCommandLine = cgroup_no_v1=all
  3. wsl --shutdown, then restart Docker Desktop.
  4. Check: docker info --format "{{.CgroupVersion}}"   (should print 2)

On Linux, use a distro that boots with cgroups v2 (the default on current
Fedora, Ubuntu, Debian and Arch).
MSG
  exit 1
fi

delegate_cgroups

mkdir -p output
echo "==> Building output/qcow2/disk.qcow2 (this takes several minutes)"
# Fedora images have no default root filesystem, hence --rootfs.
podman run --rm --privileged --pull=newer --network=host \
  --security-opt label=type:unconfined_t \
  -v "${PWD}/image/config.toml:/config.toml:ro" \
  -v "${PWD}/output:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  "${BIB_IMAGE}" \
  --type qcow2 \
  --rootfs ext4 \
  --use-librepo=True \
  --progress verbose \
  "${IMAGE}"

echo "==> Done:"
ls -lh output/qcow2/
