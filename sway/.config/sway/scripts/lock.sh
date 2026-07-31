#!/bin/bash
# Lock screen; when the user unlocks, restore brightness if idle dim left it low.

set -u

if pgrep -x swaylock >/dev/null; then
  exit 0
fi

# Daemonize so swayidle before-sleep / timeouts are not blocked until unlock
swaylock -f

# When swaylock exits (unlock), restore pre-dim brightness + power on outputs
(
  # Wait until lock is actually up (brief race after -f)
  for _ in $(seq 1 20); do
    pgrep -x swaylock >/dev/null && break
    sleep 0.05
  done
  while pgrep -x swaylock >/dev/null 2>&1; do
    sleep 0.3
  done
  ~/.config/sway/scripts/brightness-restore.sh
) &
disown
