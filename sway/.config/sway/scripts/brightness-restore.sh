#!/bin/bash
# Restore brightness after idle dim / blank / unlock / resume.

set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/sway-brightness-pre-dim"

if ! command -v brightnessctl >/dev/null; then
  exit 0
fi

# Ensure panels are on first — restoring while powered off is often ignored
if command -v swaymsg >/dev/null; then
  swaymsg "output * power on" >/dev/null 2>&1 || true
  sleep 0.25
fi

if [[ -f "$STATE" ]]; then
  val=$(cat "$STATE" 2>/dev/null || true)
  rm -f "$STATE"
  if [[ -n "${val:-}" ]]; then
    brightnessctl set "$val" >/dev/null 2>&1 || true
    exit 0
  fi
fi

# Fallback: brightnessctl's own saved state (if any)
brightnessctl -r >/dev/null 2>&1 || true
