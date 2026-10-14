#!/usr/bin/env bash
# Build the FoxHoundOS bootc image into the builder's podman storage.
# Runs inside the privileged `builder` service (via `just image`).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

IMAGE=localhost/foxhoundos:dev

echo "==> Building ${IMAGE} from image/Containerfile"
# Host networking: no netavark/iptables setup needed inside Docker.
podman build --network=host --pull=newer -t "${IMAGE}" -f image/Containerfile .

echo "==> Built ${IMAGE}"
podman images --filter "reference=${IMAGE}"
