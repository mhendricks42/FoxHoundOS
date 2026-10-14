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
