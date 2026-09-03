#!/bin/bash
# Capture menu (Omarchy-inspired). Bound to Super+Ctrl+C.
# Screenshots: region / full. Recording: region / full, optional audio. Toggle stop.

set -euo pipefail

SCRIPTS="${HOME}/.config/sway/scripts"

if pgrep -x wf-recorder >/dev/null 2>&1; then
  # While recording, the menu is a one-shot stop (same as Omarchy toggle behaviour)
  options="⏹  Stop recording"
else
  options="  Screenshot region
  Screenshot full screen
  Record region
  Record full screen
  Record region + audio
  Record full screen + audio"
fi

chosen=$(printf '%s\n' "$options" | "$SCRIPTS/wofi.sh" --dmenu --prompt "Capture" --width 360 --height 280 || true)
[[ -z "${chosen:-}" ]] && exit 0

case "$chosen" in
  *Stop*)
    "$SCRIPTS/screenrecord.sh"
    ;;
  *"Screenshot region"*)
    "$SCRIPTS/screenshot.sh" region
    ;;
  *"Screenshot full"*)
    "$SCRIPTS/screenshot.sh" full
    ;;
  *"Record region + audio"*)
    "$SCRIPTS/screenrecord.sh" region --audio
    ;;
  *"Record full screen + audio"*)
    "$SCRIPTS/screenrecord.sh" full --audio
    ;;
  *"Record region"*)
    "$SCRIPTS/screenrecord.sh" region
    ;;
  *"Record full"*)
    "$SCRIPTS/screenrecord.sh" full
    ;;
esac
