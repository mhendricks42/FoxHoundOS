# Progress

## M0: Scaffold (2026-10-14)

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

**Not verified: the M0 acceptance check is still open**
- The dev image was not built: the sandbox's network policy blocks the Fedora mirrors (`mirrors.fedoraproject.org`, `registry.fedoraproject.org`). So `just lint` / `just dev` haven't run end to end through the container.
- Nothing has been run from PowerShell on Windows. The `windows-shell` behavior and the stub recipes (`echo ...; exit 1`) still need checking there.
- To close M0, on a clean Windows box: install Git + Docker Desktop + just, then `just lint` (expect "lint: all checks passed") and `just dev` (expect a bash prompt in `/workspace`).

**Open questions**
- Product name: the repo is FoxHoundOS, but the guide says NeonOS. Kept NeonOS for now.
