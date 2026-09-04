#!/bin/bash
# Toggle the Quickshell battery popup. Falls back to the wofi menu if qs is missing.

set -u

if ! command -v qs >/dev/null 2>&1; then
  exec "$HOME/.config/sway/scripts/battery-menu.sh"
fi

if ! pgrep -f '[q]s -c battery|[q]uickshell -c battery' >/dev/null 2>&1; then
  qs -c battery >/dev/null 2>&1 &
  disown
  sleep 0.25
fi

exec qs -c battery ipc call panel toggle
