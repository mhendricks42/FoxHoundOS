#!/usr/bin/env bash
# Sourced by builder scripts; not run directly.
set -euo pipefail

# Let podman create cgroups with controllers inside the builder container.
#
# On cgroups v2 a cgroup cannot hand controllers to children while it holds
# processes itself ("no internal processes" rule). The builder container
# starts with its processes in the root of its cgroup namespace, so podman's
# containers fail with "controller `pids` is not available". Move every
# process into a leaf cgroup, then enable all controllers for children.
# Same approach as Docker's official docker-in-docker entrypoint.
delegate_cgroups() {
  local root=/sys/fs/cgroup
  [[ -f "${root}/cgroup.controllers" ]] || return 0 # cgroups v1: nothing to do
  mkdir -p "${root}/init"
  local pid
  while read -r pid; do
    echo "${pid}" > "${root}/init/cgroup.procs" 2>/dev/null || true
  done < "${root}/cgroup.procs"
  local controller
  for controller in $(< "${root}/cgroup.controllers"); do
    echo "+${controller}" > "${root}/cgroup.subtree_control" 2>/dev/null ||
      echo "warning: could not enable cgroup controller ${controller}" >&2
  done
}
