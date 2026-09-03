#!/bin/bash
# Share helpers (Omarchy-style Super+Ctrl+S lite).

set -u

choice=$(
  printf '%s\n' \
    "󰍹  Open LocalSend" \
    "  Copy LocalSend tip" \
    "  Open Screenshots folder" \
    "  Open Downloads" \
    | "$HOME/.config/sway/scripts/wofi.sh" --dmenu --prompt "Share" --width 320 --height 220 --cache-file /dev/null || true
)

[[ -z "${choice:-}" ]] && exit 0

case "$choice" in
  *LocalSend)
    if command -v localsend >/dev/null; then
      localsend &
    elif command -v localsend_app >/dev/null; then
      localsend_app &
    else
      # AUR localsend-bin desktop entry
      gtk-launch localsend 2>/dev/null \
        || notify-send "Share" "Install localsend-bin" -u critical 2>/dev/null \
        || true
    fi
    ;;
  *tip*)
    msg="Install LocalSend on the other device, same Wi‑Fi, then open LocalSend here."
    printf '%s' "$msg" | wl-copy 2>/dev/null || true
    notify-send "LocalSend" "$msg" 2>/dev/null || true
    ;;
  *Screenshots*)
    dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    mkdir -p "$dir"
    thunar "$dir" 2>/dev/null || xdg-open "$dir" 2>/dev/null || true
    ;;
  *Downloads*)
    dir="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
    mkdir -p "$dir"
    thunar "$dir" 2>/dev/null || xdg-open "$dir" 2>/dev/null || true
    ;;
esac
