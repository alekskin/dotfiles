#!/bin/bash
# Laptop lid handler for sway bindswitch.
# on  → lock then suspend
# off → restore outputs

set -u

case "${1:-}" in
  on)
    ~/.config/sway/scripts/lock.sh
    systemctl suspend
    ;;
  off)
    swaymsg "output * power on" 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 on|off" >&2
    exit 1
    ;;
esac
