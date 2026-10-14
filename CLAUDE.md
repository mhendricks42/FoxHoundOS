# NeonOS: project guide for Claude Code

NeonOS is a Linux distribution where the entire experience, from boot to shell, looks like an old CRT terminal. Firmware, bootloader, kernel console, boot splash, login and session all share one phosphor palette, one font and one visual language. The session itself is `cool-retro-term`, running fullscreen with no desktop environment.

Read this file before every task. When a decision here turns out to be wrong, update this file in the same change.

The Git repository is named **FoxHoundOS**; the product, image tags and theme names are still **NeonOS** / `neonos` until a rename is decided.

---

## 1. Environment and hard constraints

- **Development host is Windows** (Windows 11, Docker Desktop with the WSL2 backend). Most work happens through Claude Code on Windows.
- **Everything builds and runs in containers.** The only host requirements are Git, Docker Desktop, `just` (`winget install Casey.Just`; a single native binary) and a text editor. Never require installing Linux tools on the host or inside the user's WSL distro.
- **Exec bits:** a Windows checkout loses Unix exec bits. Always invoke scripts as `bash path/to/script`, never `./script`.
- **Container storage** (podman, bootc-image-builder) lives in named Docker volumes, never in the Windows bind mount: overlayfs does not work there and it is slow.
- **Real-hardware testing happens on a separate Linux machine.** Produce artifacts (ISO, disk images) that can be copied there, plus a script that runs the same QEMU test on that machine.
- **Line endings:** this repo is edited on Windows but everything runs on Linux. Enforce LF via `.gitattributes` (`* text=auto eol=lf`, binaries marked `binary`, extensionless scripts listed explicitly). A CRLF in a shell script, systemd unit, or Plymouth script is a bug; `just lint` fails on any CRLF.
- **Paths:** scripts must not assume Windows paths. Use paths relative to the repo root inside containers (`/workspace`).
- **Privileged containers:** image and ISO builds need a privileged builder container. That is acceptable inside Docker Desktop's VM, but isolate it to the `builder` service and never mount the Windows host root.
- Tool versions and flags change. Before relying on a tool's flags (bootc, bootc-image-builder, Plymouth, greetd, cage, Qt), check its current docs instead of trusting memory, and pin versions once something works.

## 2. Technical approach

**Base: Fedora bootc** (`quay.io/fedora/fedora-bootc`). The OS is defined as a `Containerfile`, built like any container image, and turned into an installable ISO and VM disk with `bootc-image-builder`. This fits a container-first workflow and gives installed systems atomic updates from our image.

Fallback, if bootc blocks a core requirement (see risks): Arch + `archiso`. Do not switch without recording the reason here.

### Boot stages and what owns them

| Stage | Owner in this repo | Notes |
|---|---|---|
| Firmware POST | Not ours | Fast boot plus hidden logo on real hardware. In QEMU, an optional custom OVMF logo. The "BIOS" the user sees is faked by `post.sh`. |
| Bootloader (GRUB) | `branding/grub/` | Phosphor theme: scanline background PNG, PF2 font, amber palette. **Risk:** bootc manages GRUB via bootupd, so investigate how far theming is supported. |
| Kernel console | kernel args + `branding/console/` | `quiet loglevel=3`, `vt.default_red/grn/blu` palette, PSF font via `vconsole.conf`. |
| Boot splash | `branding/plymouth/neon/` | Plymouth script theme: ASCII logo, block progress bar, status lines, password prompt for disk encryption, shutdown screen. It must be in the initramfs, so regenerate it with dracut in the Containerfile. |
| Fake POST | `session/post.sh` | Runs *inside* cool-retro-term, so it gets real CRT effects. Shows a banner, memory count and drive detection, then `exec`s the greeter. |
| Login | `session/greetd/` | greetd → `cage -s -- cool-retro-term --fullscreen -e post.sh` → tuigreet. |
| Session | `session/` | After login: `cage -s -- cool-retro-term --fullscreen` running the user's shell, with tmux available. Ctrl+Alt+F2 must still give a plain TTY for recovery. |
| Look and feel | `packages/cool-retro-term/` | Fork or patch it so the NeonOS profile is the built-in default. First find out where it stores settings and profiles, and prefer patching defaults over copying user config files. |

### Single source of truth for the look

`branding/palette.toml` defines the phosphor colors (foreground, dim, background, 16 console colors) and the font choice. A generator script (`tools/gen-branding`) produces every derived asset from it: GRUB theme colors, kernel `vt.default_*` args, Plymouth colors, the cool-retro-term profile and the PSF/PF2 fonts. Never hand-edit generated files. Check them into `build/generated/` or regenerate them during the build, and record which in this file.

## 3. Repository layout (target)

```
neonos/
├── CLAUDE.md
├── README.md                  # human quickstart: Windows + Docker Desktop
├── .gitattributes             # LF everywhere
├── .devcontainer/             # dev container: shellcheck, python, fonttools, qemu, podman
├── compose.yaml               # services: dev, builder (privileged), vm (qemu + noVNC)
├── justfile                   # all entry points; see section 4
├── image/
│   ├── Containerfile          # FROM fedora-bootc, installs packages, copies overlays
│   ├── kargs.d/10-neon.toml   # kernel args
│   └── config.toml            # bootc-image-builder config (user, disk layout)
├── branding/
│   ├── palette.toml
│   ├── grub/  plymouth/neon/  console/  fonts/
├── session/
│   ├── post.sh  greetd/config.toml  neon-session  tmux.conf
├── packages/
│   └── cool-retro-term/       # RPM spec + patches for the default profile
├── tools/
│   ├── gen-branding           # palette → all derived assets
│   ├── preview/               # browser simulator of the boot flow, for fast iteration
│   └── test-on-linux.sh       # runs the same QEMU test on the Linux test machine
└── output/                    # gitignored: ISOs, qcow2 images, logs
```

## 4. Commands (all run through containers)

Expose everything through `just`. Each recipe wraps `docker compose run ...` so it works the same from PowerShell, WSL, or the Linux test box.

- `just dev`: open a shell in the dev container.
- `just lint`: shellcheck, TOML/JSON validation, CRLF check, and `plymouth` script syntax check where possible.
- `just branding`: regenerate derived assets from `palette.toml`.
- `just image`: build the bootc OS image (`localhost/neonos:dev`) inside the builder container.
- `just iso`: build an installer ISO into `output/`.
- `just qcow`: build a VM disk into `output/`.
- `just vm`: boot the qcow2 in QEMU with OVMF. The display is VNC, bridged to **noVNC at http://localhost:6080**, so it can be watched from a browser on Windows. Use `/dev/kvm` when it's available (WSL2 nested virtualization) and fall back to TCG with a warning.
- `just preview`: serve `tools/preview/` on http://localhost:8080 for quick visual iteration without booting.
- `just clean`

The user should never need to know the underlying podman or bootc-image-builder commands.

Justfile rules (so recipes run identically under PowerShell and sh):
- `set windows-shell` uses PowerShell; Windows has no `sh` on PATH by default.
- Each recipe line is a plain command valid in both shells: no `&&`, no `$VAR`, no globs, no `!`. Anything with logic goes in a script under `tools/` run as `docker compose run --rm -T dev bash tools/<script>`.
- Use `-T` for non-interactive recipes so they also work without a TTY (CI).

Compose decisions:
- `dev`, `builder` and `vm` share one image, `localhost/neonos-dev:local`, built from `.devcontainer/Containerfile` (pinned to `fedora:44`). `builder` and `vm` sit behind the `build` and `vm` profiles.
- `/dev/kvm` is never listed under `devices:`, because compose fails hard when it is missing. The vm script detects it at runtime and falls back to TCG.

## 5. Milestones

Work through them in order. Each milestone ends with its acceptance check passing, a short note in `docs/progress.md`, and a commit.

**M0: Scaffold.** Repo layout, `.gitattributes`, devcontainer, `compose.yaml`, `justfile`, README with a Windows quickstart.
*Check:* `just lint` and `just dev` work from PowerShell on a clean Windows machine with only Docker Desktop and Git installed.

**M1: Bootable base.** A minimal Containerfile from fedora-bootc with greetd, cage, cool-retro-term and tuigreet installed. `just qcow` and `just vm` boot it.
*Check:* the VM boots, and you can log in at a TTY through noVNC.

**M2: CRT session.** The greetd config launches cage + cool-retro-term fullscreen with tuigreet inside; after login the user gets a fullscreen cool-retro-term shell; Ctrl+Alt+F2 still gives a plain TTY.
*Check:* the full login → shell flow works in the VM with no desktop anywhere.

**M3: Palette pipeline.** `palette.toml` plus `tools/gen-branding`; the cool-retro-term default profile comes from the palette; the console font and `vt.default_*` args are applied.
*Check:* changing the phosphor color in one file and rebuilding changes the console and the session.

**M4: Fake POST.** `post.sh` runs a typed BIOS banner, memory counter and drive detection, plus a beep if audio is available, then `exec tuigreet`. It must be skippable with any key and must not slow login by more than about 3 s.
*Check:* the POST appears with CRT effects on every boot.

**M5: Plymouth.** The `neon` script theme (logo, block progress bar, status text, LUKS password prompt, shutdown screen) is in the initramfs.
*Check:* the splash appears in the VM on boot and shutdown; `plymouthd --debug` logs show no errors.

**M6: GRUB.** Theme the boot menu. If bootc/bootupd prevents a full theme, document what is possible, implement the best available option, and record the decision here.
*Check:* the boot menu matches the palette in the VM.

**M7: Installer ISO.** `just iso` produces an Anaconda ISO that installs NeonOS; `tools/test-on-linux.sh` boots it on the Linux test machine with KVM.
*Check:* a fresh install on the Linux machine boots straight into the CRT experience.

**Later:** an OVMF custom logo for VMs, Calamares or a TUI installer themed to match, CI that builds the image and ISO on every push (GitHub Actions), signed images, and a matching shutdown/reboot experience.

## 6. Working rules for Claude Code

- One milestone at a time. Don't start the next one until the current check passes. If one is blocked, say exactly what blocks it and propose options rather than silently changing approach.
- Prefer small, reviewable commits with clear messages.
- Every shell script: `#!/usr/bin/env bash`, `set -euo pipefail`, shellcheck clean.
- Don't commit build outputs, ISOs, or secrets. `output/` is gitignored.
- When a build step needs root or privileges, keep it inside the `builder` service and explain why in a comment.
- When something only works with KVM or on real hardware, say so plainly in `docs/progress.md` rather than marking the milestone done.
- Keep the README's Windows quickstart accurate after every milestone.
- Keep the user's iteration loop fast: visual tweaks should be checkable with `just preview` or a rebuilt VM, not a full ISO.
