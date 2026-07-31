#!/bin/bash
# Save current brightness and dim (used by swayidle).

set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/sway-brightness-pre-dim"
pct="${1:-15}"

if ! command -v brightnessctl >/dev/null; then
  exit 0
fi

# Only save once per dim cycle so a second dim can't overwrite with already-low value
if [[ ! -f "$STATE" ]]; then
  brightnessctl g >"$STATE" 2>/dev/null || true
  # also stash via brightnessctl's built-in save as backup
  brightnessctl -s >/dev/null 2>&1 || true
fi

brightnessctl set "${pct}%" >/dev/null 2>&1 || true
