#!/bin/bash
# Waybar custom module: show icon when idle-lock daemon is OFF (like Omarchy).

if pgrep -x swayidle >/dev/null; then
  echo '{"text": "", "tooltip": "Idle lock enabled"}'
else
  echo '{"text": "󱫖", "tooltip": "Idle lock disabled — Super+Ctrl+I to enable", "class": "active"}'
fi
