#!/usr/bin/env bash
# Turn localhost/foxhoundos:dev into output/qcow2/disk.qcow2 with
# bootc-image-builder. Runs inside the privileged `builder` service (via
# `just qcow`); bootc-image-builder itself needs --privileged to set up loop
# devices and mount the filesystems it writes.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

IMAGE=localhost/foxhoundos:dev
# Pin by digest once a build is known good.
BIB_IMAGE=quay.io/centos-bootc/bootc-image-builder:latest

if ! podman image exists "${IMAGE}"; then
  echo "error: ${IMAGE} not found; run 'just image' first" >&2
  exit 1
fi

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
