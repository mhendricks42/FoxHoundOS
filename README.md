# FoxHoundOS

A Linux distribution that looks like an old CRT terminal from firmware to
shell. See [CLAUDE.md](CLAUDE.md) for the design and [docs/progress.md](docs/progress.md)
for status.

## Quickstart (Windows 11)

You need exactly three things on the host:

1. **Git for Windows**: <https://git-scm.com/download/win>
2. **Docker Desktop** with the WSL2 backend (the default): <https://www.docker.com/products/docker-desktop/>
3. **just**, a small command runner: in PowerShell run `winget install Casey.Just`, then open a new terminal.

Nothing else: no WSL distro setup, no Linux tools on Windows.

```powershell
git clone <this repo> FoxHoundOS
cd FoxHoundOS
just lint    # first run builds the dev image (a few minutes)
just dev     # shell inside the dev container, repo mounted at /workspace
```

`just` with no arguments lists every command.

### Available now (M0)

| Command | What it does |
|---|---|
| `just dev` | Shell in the dev container (shellcheck, python, fonttools, podman, qemu) |
| `just lint` | shellcheck, TOML/JSON/YAML syntax, CRLF check, justfile parse |
| `just rebuild` | Rebuild the dev image after changing `.devcontainer/` |
| `just clean` | Delete `output/` contents and stopped containers |

`just image`, `just qcow`, `just vm`, `just iso`, `just branding` and
`just preview` exist but report "not implemented yet" until their milestone.

### VS Code

Open the folder and choose **Reopen in Container**; it uses the same `dev`
service as `just dev`.

### Checking for KVM (needed later for fast VMs)

```powershell
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

A `crw-rw----` line means VMs will use KVM. An error means they will fall back
to slow software emulation. To fix it, make sure virtualization is enabled in
your BIOS and `%UserProfile%\.wslconfig` doesn't set `nestedVirtualization=false`,
then run `wsl --shutdown` and restart Docker Desktop.

## Troubleshooting

- **`just` is not recognized**: open a new terminal after `winget install`.
- **Script fails with `$'\r': command not found`**: a file got CRLF line
  endings. Run `git add --renormalize .` and commit; `just lint` reports these.
- **Port 8080 or 6080 already in use**: stop the other program, or change the
  left-hand port in `compose.yaml`.
