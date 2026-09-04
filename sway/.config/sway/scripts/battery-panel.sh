#!/bin/bash
# Toggle the Quickshell battery popup. Falls back to the wofi menu if qs is missing.

set -u

if ! command -v qs >/dev/null 2>&1; then
  exec "$HOME/.config/sway/scripts/battery-menu.sh"
fi

# -n makes qs exit immediately if this config is already running, so the race
# between the check and the launch cannot leave two instances behind. The
# pgrep guard only avoids the pointless fork in the common case.
if ! pgrep -x qs >/dev/null 2>&1; then
  qs -n -c battery >/dev/null 2>&1 &
  disown
  sleep 0.25
fi

exec qs -c battery ipc call panel toggle
