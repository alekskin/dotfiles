#!/bin/bash
# Toggle mako do-not-disturb (Omarchy-style Super+Ctrl+,).

set -u

if ! command -v makoctl >/dev/null; then
  notify-send "Notifications" "mako/makoctl not installed" -u critical 2>/dev/null || true
  exit 1
fi

makoctl mode -t do-not-disturb 2>/dev/null || true

if makoctl mode 2>/dev/null | grep -q 'do-not-disturb'; then
  notify-send -u low "󰂛  Notifications silenced"
else
  notify-send -u low "󰂚  Notifications enabled"
fi
