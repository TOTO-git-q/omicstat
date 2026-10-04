#!/usr/bin/env bash
# Resolve every UNPINNED row of env/layers/github_pins.txt to the current HEAD
# commit of the default branch (git ls-remote), ONCE. Commit the result; the
# pins never float afterwards.
#   bash env/pin_github.sh               resolve UNPINNED rows
#   bash env/pin_github.sh --from-lock   also append transitive GitHub packages
#                                        recorded in env/pkg_lock.csv
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PINS="$ROOT/env/layers/github_pins.txt"
tmp="$(mktemp)"
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then echo "$line" >> "$tmp"; continue; fi
  read -r layer pkg repo sha <<< "$line"
  if [[ "$sha" == "UNPINNED" ]]; then
    sha="$(git ls-remote "https://github.com/$repo" HEAD | cut -f1)"
    [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "could not resolve $repo" >&2; exit 1; }
    echo "pinned $pkg -> $repo@$sha"
  fi
  printf '%-4s %-13s %-30s %s\n' "$layer" "$pkg" "$repo" "$sha" >> "$tmp"
done < "$PINS"
if [[ "${1:-}" == "--from-lock" && -f "$ROOT/env/pkg_lock.csv" ]]; then
  python3 - "$ROOT/env/pkg_lock.csv" "$tmp" <<'PY'
import csv, sys
lock, pins = sys.argv[1], sys.argv[2]
have = {l.split()[1] for l in open(pins) if l.strip() and not l.lstrip().startswith("#")}
extra = []
for r in csv.DictReader(open(lock)):
    if r["source"] == "github" and r["package"] not in have:
        repo = r["repository"].split("@")[0]
        extra.append(f"DEP  {r['package']:<13} {repo:<30} {r['remote_sha']}\n")
lines = open(pins).read().splitlines(keepends=True)
# transitive deps go BEFORE the packages that need them
first = next(i for i, l in enumerate(lines) if l.strip() and not l.lstrip().startswith("#"))
open(pins, "w").writelines(lines[:first] + extra + lines[first:])
print(f"appended {len(extra)} transitive GitHub pins")
PY
fi
mv "$tmp" "$PINS"
