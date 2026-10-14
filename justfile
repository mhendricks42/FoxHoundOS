# FoxHoundOS entry points. Every recipe wraps `docker compose`, so it behaves the
# same from PowerShell, WSL, or the Linux test machine.
#
# Recipes are single-line commands understood by both PowerShell and sh:
# no `&&`, no `$VAR`, no globs. Real logic goes in scripts under tools/,
# invoked as `bash tools/...` (exec bits are lost on Windows checkouts).

set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# List recipes
default:
    @just --list

# Open a shell in the dev container
dev:
    docker compose run --rm dev

# Shellcheck, TOML/JSON/YAML validation, CRLF check
lint:
    docker compose run --rm -T dev bash tools/lint.sh

# Rebuild the dev container image (after editing .devcontainer/)
rebuild:
    docker compose build dev

# Regenerate derived assets from branding/palette.toml (M3)
branding:
    @echo "just branding: not implemented yet (milestone M3)"; exit 1

# Build the bootc OS image localhost/foxhoundos:dev (M1)
image:
    @echo "just image: not implemented yet (milestone M1)"; exit 1

# Build an installer ISO into output/ (M7)
iso:
    @echo "just iso: not implemented yet (milestone M7)"; exit 1

# Build a qcow2 VM disk into output/ (M1)
qcow:
    @echo "just qcow: not implemented yet (milestone M1)"; exit 1

# Boot the qcow2 in QEMU, watch at http://localhost:6080 (M1)
vm:
    @echo "just vm: not implemented yet (milestone M1)"; exit 1

# Serve the boot-flow simulator at http://localhost:8080
preview:
    @echo "just preview: not implemented yet"; exit 1

# Delete build outputs and stopped containers (keeps builder storage)
clean:
    docker compose run --rm -T dev find output -mindepth 1 -not -name .gitkeep -delete
    docker compose down --remove-orphans
