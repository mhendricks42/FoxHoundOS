#!/usr/bin/env bash
# Boot output/qcow2/disk.qcow2 in QEMU with OVMF and serve the display
# through noVNC on port 6080. Runs in the `vm` service (via `just vm`).
#
# The disk is used as a read-only backing file for a throwaway overlay, so
# every boot starts from the freshly built image.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

DISK=output/qcow2/disk.qcow2
SERIAL_LOG=output/vm-serial.log
RUN_DIR=/var/tmp/foxhoundos-vm
MEM=4096
CPUS=4

if [[ ! -f "${DISK}" ]]; then
  echo "error: ${DISK} not found; run 'just qcow' first" >&2
  exit 1
fi

# --- KVM -------------------------------------------------------------------
# compose allows access to char device 10:232 (device_cgroup_rules) but
# cannot pass /dev/kvm conditionally, so create the node here and probe it.
# Opening it fails if the host has no KVM, and we fall back to TCG.
accel=tcg
cpu=max
[[ -e /dev/kvm ]] || mknod /dev/kvm c 10 232 2>/dev/null || true
if [[ -c /dev/kvm ]] && { exec 3<>/dev/kvm; } 2>/dev/null; then
  exec 3>&-
  accel=kvm
  cpu=host
  echo "==> KVM available: hardware acceleration on"
else
  echo "WARNING: /dev/kvm not usable; falling back to TCG (software emulation)."
  echo "WARNING: expect a very slow boot. See README 'Checking for KVM'."
fi

# --- Firmware --------------------------------------------------------------
# OVMF file names differ between distros and releases; take the first pair
# that exists (Fedora, Debian/Ubuntu, Arch).
ovmf_code=""
ovmf_vars=""
for pair in \
  /usr/share/edk2/ovmf/OVMF_CODE.fd:/usr/share/edk2/ovmf/OVMF_VARS.fd \
  /usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2:/usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2 \
  /usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd \
  /usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd \
  /usr/share/edk2/x64/OVMF_CODE.4m.fd:/usr/share/edk2/x64/OVMF_VARS.4m.fd; do
  if [[ -f "${pair%%:*}" && -f "${pair##*:}" ]]; then
    ovmf_code=${pair%%:*}
    ovmf_vars=${pair##*:}
    break
  fi
done
if [[ -z "${ovmf_code}" ]]; then
  echo "error: no OVMF firmware found (install edk2-ovmf / ovmf)" >&2
  exit 1
fi
fw_format=raw
[[ "${ovmf_code}" == *.qcow2 ]] && fw_format=qcow2

# --- Display -----------------------------------------------------------------
# virtio-vga is a separate module on some distros (Fedora:
# qemu-device-display-virtio-vga); fall back to the built-in std VGA.
display_dev=(-device virtio-vga)
if ! qemu-system-x86_64 -device help 2>/dev/null | grep -q '"virtio-vga"'; then
  echo "WARNING: QEMU has no virtio-vga device; using standard VGA instead."
  display_dev=(-vga std)
fi

# --- Throwaway state -------------------------------------------------------
rm -rf "${RUN_DIR}"
mkdir -p "${RUN_DIR}"
cp "${ovmf_vars}" "${RUN_DIR}/vars.${fw_format}"
qemu-img create -q -f qcow2 -F qcow2 -b "${PWD}/${DISK}" "${RUN_DIR}/overlay.qcow2"
: > "${SERIAL_LOG}"

# --- noVNC -----------------------------------------------------------------
websockify --web /usr/share/novnc 0.0.0.0:6080 127.0.0.1:5900 \
  > "${RUN_DIR}/websockify.log" 2>&1 &
websockify_pid=$!
trap 'kill "${websockify_pid}" 2>/dev/null || true' EXIT

echo "==> Open http://localhost:6080/vnc.html?autoconnect=1&resize=scale"
echo "==> Login: foxhound / foxhound   (Ctrl+C here stops the VM)"
echo "==> Serial console log: ${SERIAL_LOG}"

qemu-system-x86_64 \
  -name foxhoundos \
  -machine "q35,accel=${accel}" \
  -cpu "${cpu}" \
  -m "${MEM}" \
  -smp "${CPUS}" \
  -drive "if=pflash,format=${fw_format},readonly=on,file=${ovmf_code}" \
  -drive "if=pflash,format=${fw_format},file=${RUN_DIR}/vars.${fw_format}" \
  -drive "if=virtio,format=qcow2,file=${RUN_DIR}/overlay.qcow2" \
  "${display_dev[@]}" \
  -device qemu-xhci -device usb-tablet \
  -nic user,model=virtio-net-pci \
  -display vnc=127.0.0.1:0 \
  -serial "file:${SERIAL_LOG}"
