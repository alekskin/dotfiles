#!/bin/bash
# Unified system / trigger menu (Omarchy-style Super+Escape).

set -u
S="$HOME/.config/sway/scripts"

choice=$(
  printf '%s\n' \
    "  App launcher" \
    "  Capture" \
    "  Clipboard history" \
    "  Share (LocalSend)" \
    "  Keybindings" \
    "󰖩  Wi‑Fi" \
    "  Bluetooth" \
    "  Audio (wiremix)" \
    "󰌾  Lock" \
    "󱫖  Toggle idle lock" \
    "󰔎  Toggle night light" \
    "󰂛  Toggle notifications" \
    "󰓅  Cycle power profile" \
    "  Power menu" \
    | "$S/wofi.sh" --dmenu --prompt "System" --width 360 --height 480 --cache-file /dev/null || true
)

[[ -z "${choice:-}" ]] && exit 0

case "$choice" in
  *"App launcher"*)
    "$S/wofi.sh" --show run | xargs -r swaymsg exec --
    ;;
  *Capture*)
    "$S/capture-menu.sh"
    ;;
  *Clipboard*)
    "$S/clipboard-menu.sh"
    ;;
  *Share*)
    "$S/share-menu.sh"
    ;;
  *Keybindings*)
    "$S/keybindings-menu.sh"
    ;;
  *Wi*)
    rfkill unblock wifi 2>/dev/null || true
    "$S/floating-tui.sh" impala
    ;;
  *Bluetooth*)
    rfkill unblock bluetooth 2>/dev/null || true
    "$S/floating-tui.sh" bluetui
    ;;
  *Audio*)
    "$S/floating-tui.sh" wiremix
    ;;
  *Lock*)
    "$S/lock.sh"
    ;;
  *"idle lock"*)
    "$S/toggle-idle.sh"
    ;;
  *"night light"*)
    "$S/toggle-nightlight.sh"
    ;;
  *notifications*)
    "$S/toggle-notifications.sh"
    ;;
  *"power profile"*)
    "$S/power-profile.sh" cycle
    ;;
  *Power*)
    "$S/power-menu.sh"
    ;;
esac
