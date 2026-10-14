# Progress

## M0: Scaffold (2026-10-14), done

**Done**
- Repo layout from CLAUDE.md §3 (empty dirs hold `.gitkeep`).
- `.gitattributes` forcing LF, binaries marked; `.editorconfig`; `.gitignore` (output/, secrets).
- Dev image `.devcontainer/Containerfile` (Fedora 44: just, ShellCheck, python3 + pyyaml + fonttools, podman, qemu, OVMF) and `devcontainer.json` pointing at the compose `dev` service.
- `compose.yaml`: `dev`; `builder` (privileged, `build` profile, named volume for container storage); `vm` (`vm` profile, port 6080, no hard `/dev/kvm` dependency).
- `justfile` with PowerShell as the Windows shell; `dev`, `lint`, `rebuild`, `clean` work; the later-milestone recipes are stubs that exit 1.
- `tools/lint.sh`: CRLF, shebang + strict mode, shellcheck, TOML/JSON/YAML parse, justfile parse, Plymouth placeholder.
- README Windows quickstart. CLAUDE.md updated: `just` is a host requirement, justfile/compose rules, exec-bit and storage notes.

**Verified (in a Linux cloud sandbox, not on Windows)**
- `tools/lint.sh` passes on the repo and fails correctly on a test file with CRLF, a bad shebang, no strict mode, a shellcheck error, and invalid TOML.
- `docker compose config` is valid; all three services resolve with their profiles.
- `just --summary` parses the justfile.

**Windows results (2026-10-14)**
- `just lint` from PowerShell: dev image built in ~35 s, "lint: all checks passed".
- Compose printed a harmless `Get "http://localhost/v2/"` warning because it tried to pull the `localhost/...` image before building it. Fixed with `pull_policy: never` (tested: builds when the image is missing, no pull attempt, quiet afterwards).
- After `git pull`: `just lint` passes with no warning.
- `just dev` from PowerShell: bash prompt in `/workspace`, exits cleanly.
- KVM: `docker run --rm --device /dev/kvm alpine ls -l /dev/kvm` shows `crw-rw---- root 993 10,232`, so Docker Desktop containers can use KVM on this host. M1's `just vm` will use it, with a TCG fallback kept for other machines.

**M0 status: DONE.** Acceptance check passed on Windows 11 + Docker Desktop.

**Earlier sandbox notes**
- The dev image was not built: the sandbox's network policy blocks the Fedora mirrors (`mirrors.fedoraproject.org`, `registry.fedoraproject.org`). So `just lint` / `just dev` haven't run end to end through the container.
- Nothing has been run from PowerShell on Windows. The `windows-shell` behavior and the stub recipes (`echo ...; exit 1`) still need checking there.
- To close M0, on a clean Windows box: install Git + Docker Desktop + just, then `just lint` (expect "lint: all checks passed") and `just dev` (expect a bash prompt in `/workspace`).

## Rename to FoxHoundOS (2026-10-14)

Product renamed from NeonOS to FoxHoundOS everywhere: image tags (`localhost/foxhoundos:dev`, `localhost/foxhoundos-dev:local`), compose project `foxhoundos`, Plymouth theme `foxhound`, `session/foxhound-session`, `image/kargs.d/10-foxhound.toml`.

## M1: Bootable base (2026-10-14), written, not yet verified

**Done**
- `image/Containerfile`: `fedora-bootc:44` plus greetd, tuigreet, cage, cool-retro-term; `bootc container lint`. greetd installed but not enabled (M2).
- `image/kargs.d/10-foxhound.toml`: serial + tty0 console. `image/config.toml`: test user `foxhound`/`foxhound`.
- `tools/build-image.sh` (`just image`): podman build in the privileged builder.
- `tools/build-qcow.sh` (`just qcow`): bootc-image-builder → `output/qcow2/disk.qcow2`.
- `tools/vm.sh` (`just vm`): QEMU q35 + OVMF + virtio-vga, throwaway overlay, noVNC on 6080, serial log in `output/vm-serial.log`, KVM probe with TCG fallback.
- Dev image gained novnc, websockify and a podman config for running inside Docker.

**Verified here (Linux sandbox)**
- Lint and `docker compose config` pass.
- KVM probe fallback: in a compose container with the same cgroup rule and no host KVM, the probe picks TCG and prints the warning.

**Not verified**
- Nothing was built or booted: this sandbox can't reach quay.io or the Fedora mirrors. The bootc-image-builder flags come from upstream docs snippets and memory; the current upstream README moved and could not be fetched.
- Fedora 44 package names: greetd, tuigreet (0.9.1-7.fc44) and cool-retro-term are confirmed on packages.fedoraproject.org; `cage` is not confirmed.
- Podman-in-Docker and bootc-image-builder nested in it are untested on Docker Desktop.

**Acceptance check (to run on Windows):** `just qcow`, `just vm`, open noVNC, log in as foxhound at the TTY.

### M1 first Windows run (2026-10-14)
- `just image` worked: podman inside the builder pulled fedora-bootc:44, installed all four packages (so `cage` exists in Fedora 44) and passed `bootc container lint`.
- `just qcow` failed: bootc-image-builder's internal podman reported `Cgroups v1 not supported`. Docker Desktop's WSL2 VM was on cgroups v1.
- Fix: the one-time `.wslconfig` setting `kernelCommandLine = cgroup_no_v1=all` (README). `tools/build-qcow.sh` now checks the cgroup version up front and prints these steps.
