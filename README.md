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

**One-time setting for VM builds (`just qcow`):** the build tools need cgroups
v2, which Docker Desktop's WSL2 VM may not use by default. In PowerShell:

```powershell
wsl --update
notepad $env:USERPROFILE\.wslconfig
```

Add these lines and save. If the file already has a `[wsl2]` section, add only
the second line under it:

```ini
[wsl2]
kernelCommandLine = cgroup_no_v1=all
```

Then run `wsl --shutdown`, restart Docker Desktop, and check that
`docker info --format "{{.CgroupVersion}}"` prints `2`. This setting applies
to all your WSL distros; current distros and Docker handle cgroups v2 fine.

```powershell
git clone <this repo> FoxHoundOS
cd FoxHoundOS
just lint    # first run builds the dev image (a few minutes)
just dev     # shell inside the dev container, repo mounted at /workspace
```

`just` with no arguments lists every command.

### Available now (M1)

| Command | What it does |
|---|---|
| `just dev` | Shell in the dev container (shellcheck, python, fonttools, podman, qemu) |
| `just lint` | shellcheck, TOML/JSON/YAML syntax, CRLF check, justfile parse |
| `just image` | Build the OS image `localhost/foxhoundos:dev` |
| `just qcow` | Build the image, then a VM disk at `output/qcow2/disk.qcow2` |
| `just vm` | Boot that disk; watch it at <http://localhost:6080/vnc.html?autoconnect=1&resize=scale> |
| `just rebuild` | Rebuild the dev image (image/qcow/vm do this automatically) |
| `just clean` | Delete `output/` contents and stopped containers |

`just iso`, `just branding` and `just preview` report "not implemented yet"
until their milestone.

### Boot a VM

```powershell
just qcow   # first run downloads ~2-3 GB and takes 10-20 minutes
just vm     # then open the noVNC link it prints
```

Log in as **foxhound / foxhound** (a test-only account from
`image/config.toml`; never ship an image built with it). Press Ctrl+C in the
terminal running `just vm` to stop the VM. Each boot starts from the built
disk, so changes made inside the VM are thrown away. The VM's serial console
is written to `output/vm-serial.log`.

Build state (base images, our image) lives in the Docker volume
`foxhoundos_builder-storage`, so rebuilds are incremental. To reclaim the
space: `docker volume rm foxhoundos_builder-storage`.

### VS Code

Open the folder and choose **Reopen in Container**; it uses the same `dev`
service as `just dev`.

### Checking for KVM (needed later for fast VMs)

```powershell
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

A `crw-rw----` line means VMs will use KVM. An error means they will fall back
to slow software emulation (`just vm` prints a warning). To fix it, make sure virtualization is enabled in
your BIOS and `%UserProfile%\.wslconfig` doesn't set `nestedVirtualization=false`,
then run `wsl --shutdown` and restart Docker Desktop.

## Troubleshooting

- **`just qcow` says "Docker is running with cgroups v1"**: apply the
  one-time `.wslconfig` setting above.

- **`just` is not recognized**: open a new terminal after `winget install`.
- **Script fails with `$'\r': command not found`**: a file got CRLF line
  endings. Run `git add --renormalize .` and commit; `just lint` reports these.
- **Port 8080 or 6080 already in use**: stop the other program, or change the
  left-hand port in `compose.yaml`.
