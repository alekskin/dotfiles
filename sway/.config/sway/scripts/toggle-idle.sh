#!/bin/bash
# Toggle idle locking (Omarchy-style Super+Ctrl+I).

set -u

if pgrep -x swayidle >/dev/null; then
  pkill -x swayidle
  notify-send -u low "󱫖  Idle lock off" 2>/dev/null || true
else
  ~/.config/sway/scripts/idle-daemon.sh &
  disown
  notify-send -u low "󱫖  Idle lock on" 2>/dev/null || true
fi
