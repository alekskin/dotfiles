#!/bin/bash

chosen=$(printf "󰤄  Suspend\n󰑓  Reboot\n󰐥  Power off" \
  | wofi --dmenu --prompt "" --width 200 --height 150 --cache-file /dev/null)

case "$chosen" in
  *Suspend)   systemctl suspend ;;
  *Reboot)    systemctl reboot ;;
  *"Power off") systemctl poweroff ;;
esac
