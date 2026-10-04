#!/usr/bin/env bash
# Run ON GT103 before a deploy that changes the seed or the method map (their hashes are bound by
# reference.sqlite / harvest.sqlite). Stops ONLY the omicstat-reference compose service, backs up
# ~/omic-infra-reference/runtime/ to runtime-backups/ (tar + sha256), moves runtime/data aside (never
# deletes it) and leaves an empty runtime/data for fresh sqlite files. Requires --yes.
#   bash ~/omic-infra-reference/release/reset_runtime_gt103.sh --yes <label>
set -Eeuo pipefail
[ "${1:-}" = "--yes" ] || { echo "usage: $0 --yes <label>"; exit 2; }
LABEL="${2:-reset}"
BASE="$HOME/omic-infra-reference"
REL="$BASE/release"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$HOME/omic-build-logs/infra-reference" "$BASE/runtime-backups"
exec > >(tee -a "$HOME/omic-build-logs/infra-reference/reset-$STAMP.log") 2>&1
grep -q "^name: omicstat-reference$" "$REL/compose.yaml" || { echo "not the omicstat-reference compose file"; exit 1; }
echo "[$STAMP] stopping omicstat-reference (compose stop, this project only)"
docker compose -f "$REL/compose.yaml" stop
TAR="$BASE/runtime-backups/runtime-$STAMP-$LABEL.tar"
tar -C "$BASE" -cf "$TAR" runtime
sha256sum "$TAR" > "$TAR.sha256"
sha256sum -c "$TAR.sha256"
tar -tf "$TAR" | head -20
mv "$BASE/runtime/data" "$BASE/runtime/data.$LABEL-$STAMP"
mkdir -p "$BASE/runtime/data"
echo "backup: $TAR ; old data kept at runtime/data.$LABEL-$STAMP ; fresh runtime/data created"
