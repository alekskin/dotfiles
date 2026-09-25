#!/bin/bash
# Needs iw (installed by ~/arch packages.txt).
link=$(iw dev wlan0 link 2>/dev/null)
ssid=$(echo "$link" | grep -oP 'SSID: \K.*')
signal=$(echo "$link" | grep -oP 'signal: -\K\d+')

if [ -z "$ssid" ]; then
  printf '{"text": " ", "alt": "disconnected", "tooltip": "Disconnected", "class": "disconnected"}\n'
  exit 0
fi

# $signal is dBm without the minus sign: bigger means weaker.
if [ "${signal:-100}" -ge 80 ]; then
  icon="󰤯"
elif [ "$signal" -ge 70 ]; then
  icon="󰤟"
elif [ "$signal" -ge 55 ]; then
  icon="󰤢"
elif [ "$signal" -ge 40 ]; then
  icon="󰤥"
else
  icon="󰤨"
fi

printf '{"text":"%s","alt":"connected","tooltip":"%s (-%s dBm)","class":"connected"}\n' \
  "$icon" "$ssid" "$signal"
