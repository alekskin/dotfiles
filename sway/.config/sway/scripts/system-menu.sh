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
    | wofi --dmenu --prompt "System" --width 360 --height 480 --cache-file /dev/null || true
)

[[ -z "${choice:-}" ]] && exit 0

case "$choice" in
  *"App launcher"*)
    wofi --show run | xargs -r swaymsg exec --
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
    foot --app-id=floating-tui -e impala
    ;;
  *Bluetooth*)
    rfkill unblock bluetooth 2>/dev/null || true
    foot --app-id=floating-tui -e bluetui
    ;;
  *Audio*)
    foot --app-id=floating-tui -e wiremix
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
