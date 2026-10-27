#!/usr/bin/env bash
# Install the monthly digest as a systemd USER timer (no sudo). Idempotent; run on GT103.
#   bash ~/omic-infra-reference/release/systemd/install_digest_timer.sh
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
UNITS="$HOME/.config/systemd/user"
mkdir -p "$UNITS" "$HOME/omic-infra-reference/runtime/reports"
cp "$HERE/omicstat-reference-digest.service" "$HERE/omicstat-reference-digest.timer" "$UNITS/"
systemctl --user daemon-reload
systemctl --user enable --now omicstat-reference-digest.timer
systemctl --user list-timers omicstat-reference-digest.timer --no-pager
