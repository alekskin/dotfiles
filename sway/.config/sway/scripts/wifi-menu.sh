#!/bin/bash
# List visible wifi networks, pick one with wofi, connect via nmcli

list=$(nmcli -t -f SSID,SECURITY,SIGNAL device wifi list --rescan yes 2>/dev/null | while IFS=: read -r ssid sec signal; do
  [[ -z "$ssid" ]] && continue
  echo "$ssid  ($sec, ${signal}%)"
done)

chosen=$(echo "$list" | wofi --dmenu --prompt "Wi-Fi" --width 400 --height 300 --cache-file /dev/null 2>/dev/null)
[[ -z "$chosen" ]] && exit 0

ssid=$(echo "$chosen" | sed 's/  (.*)//')
nmcli device wifi connect "$ssid" 2>/dev/null || nmcli device wifi connect "$ssid" --ask
