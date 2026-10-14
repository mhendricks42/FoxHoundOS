#!/usr/bin/env bash
# Repo-wide lint. Runs inside the dev container via `just lint`.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

failures=0
fail() {
  echo "  FAIL: $*"
  failures=$((failures + 1))
}
section() { printf '\n== %s\n' "$1"; }

# Tracked plus new, not-ignored files.
mapfile -t files < <(git ls-files --cached --others --exclude-standard | sort -u)
existing=()
for f in "${files[@]}"; do
  [[ -f "$f" ]] && existing+=("$f")
done
files=("${existing[@]}")

section "Line endings (no CRLF in text files)"
for f in "${files[@]}"; do
  if grep -Iq $'\r' "$f"; then
    fail "$f contains CRLF"
  fi
done

section "Shell scripts (shebang, strict mode, shellcheck)"
scripts=()
for f in "${files[@]}"; do
  first=$(head -n1 "$f" 2>/dev/null || true)
  if [[ "$f" == *.sh || "$first" =~ ^\#!.*(ba)?sh ]]; then
    scripts+=("$f")
  fi
done
for f in "${scripts[@]}"; do
  [[ "$(head -n1 "$f")" == "#!/usr/bin/env bash" ]] || fail "$f: shebang must be #!/usr/bin/env bash"
  grep -q '^set -euo pipefail' "$f" || fail "$f: missing 'set -euo pipefail'"
done
if ((${#scripts[@]})); then
  shellcheck --external-sources "${scripts[@]}" || fail "shellcheck reported issues"
fi
echo "  ${#scripts[@]} script(s) checked"

section "TOML / JSON / YAML syntax"
python3 - "${files[@]}" <<'PY' || fail "structured file validation"
import json, sys, tomllib, yaml
bad = 0
for path in sys.argv[1:]:
    try:
        if path.endswith(".toml"):
            with open(path, "rb") as fh:
                tomllib.load(fh)
        elif path.endswith(".json"):
            with open(path, encoding="utf-8") as fh:
                json.load(fh)
        elif path.endswith((".yaml", ".yml")):
            with open(path, encoding="utf-8") as fh:
                yaml.safe_load(fh)
        else:
            continue
        print(f"  ok   {path}")
    except Exception as exc:
        print(f"  FAIL: {path}: {exc}")
        bad += 1
sys.exit(1 if bad else 0)
PY

section "justfile parses"
just --justfile justfile --summary >/dev/null || fail "justfile does not parse"

section "Plymouth scripts"
plymouth_scripts=()
for f in "${files[@]}"; do
  [[ "$f" == *.script ]] && plymouth_scripts+=("$f")
done
# No offline parser for Plymouth's script language exists; a real check
# (plymouthd --debug in the VM) arrives with M5.
echo "  ${#plymouth_scripts[@]} file(s); syntax check not available until M5"

echo
if ((failures)); then
  echo "lint: ${failures} problem(s)"
  exit 1
fi
echo "lint: all checks passed"
