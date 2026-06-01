#!/bin/bash
link=$(iw dev wlan0 link 2>/dev/null)
ssid=$(echo "$link" | grep -oP 'SSID: \K.*')
signal=$(echo "$link" | grep -oP 'signal: -\K\d+')

if [ -z "$ssid" ]; then
  printf '{"text": " ", "alt": "disconnected", "tooltip": "Disconnected", "class": "disconnected"}\n'
  exit 0
fi

if [ "$signal" -le 80 ]; then
  icon="󰤯"
elif [ "$signal" -le 70 ]; then
  icon="󰤟"
elif [ "$signal" -le 55 ]; then
  icon="󰤢"
elif [ "$signal" -le 40 ]; then
  icon="󰤥"
else
  icon="󰤨"
fi

printf '{"text":"%s","alt":"connected","tooltip":"%s (%s%%)","class":"connected"}\n' \
  "$icon" "$ssid" "$signal"
