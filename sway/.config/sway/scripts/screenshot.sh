#!/bin/bash
# Capture region or focused output → file + clipboard; open satty editor if available.
# Usage: screenshot.sh [region|full]

set -euo pipefail

mode="${1:-region}"

need() {
  if ! command -v "$1" >/dev/null; then
    notify-send "Screenshot" "Missing package providing: $1" -u critical 2>/dev/null || true
    exit 1
  fi
}

need grim
need wl-copy
need notify-send

outdir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$outdir"
filepath="$outdir/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"

case "$mode" in
  full)
    if command -v swaymsg >/dev/null && command -v jq >/dev/null; then
      output=$(swaymsg -t get_outputs -r | jq -r '.[] | select(.focused == true) | .name')
      if [[ -n "${output:-}" && "$output" != "null" ]]; then
        grim -o "$output" "$filepath"
      else
        grim "$filepath"
      fi
    else
      grim "$filepath"
    fi
    ;;
  region|*)
    need slurp
    geo=$(slurp 2>/dev/null) || exit 0
    [[ -z "${geo:-}" ]] && exit 0
    grim -g "$geo" "$filepath"
    ;;
esac

wl-copy <"$filepath"

# Omarchy-like: optional annotate/edit with satty
if command -v satty >/dev/null; then
  satty --filename "$filepath" \
    --output-filename "$filepath" \
    --early-exit \
    --actions-on-enter save-to-clipboard \
    --copy-command 'wl-copy' \
    --save-after-copy \
    >/dev/null 2>&1 || true
  # refresh clipboard if file updated
  [[ -f "$filepath" ]] && wl-copy <"$filepath"
  notify-send "Screenshot" "Saved\n$filepath" -i "$filepath" -t 2500 2>/dev/null || true
else
  notify-send "Screenshot" "Saved & copied\n$filepath" -i "$filepath" -t 2500 2>/dev/null || true
fi
