#!/bin/bash
# Volume / brightness helpers with swayosd if available.
# Usage: media-keys.sh vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down

set -u

case "${1:-}" in
  vol-up)
    if command -v swayosd-client >/dev/null; then
      swayosd-client --output-volume raise
    else
      pactl set-sink-volume @DEFAULT_SINK@ +5%
    fi
    ;;
  vol-down)
    if command -v swayosd-client >/dev/null; then
      swayosd-client --output-volume lower
    else
      pactl set-sink-volume @DEFAULT_SINK@ -5%
    fi
    ;;
  vol-mute)
    if command -v swayosd-client >/dev/null; then
      swayosd-client --output-volume mute-toggle
    else
      pactl set-sink-mute @DEFAULT_SINK@ toggle
    fi
    ;;
  mic-mute)
    if command -v swayosd-client >/dev/null; then
      swayosd-client --input-volume mute-toggle
    else
      pactl set-source-mute @DEFAULT_SOURCE@ toggle
    fi
    ;;
  bright-up)
    if command -v swayosd-client >/dev/null; then
      swayosd-client --brightness raise
    else
      brightnessctl set 10%+
    fi
    ;;
  bright-down)
    if command -v swayosd-client >/dev/null; then
      swayosd-client --brightness lower
    else
      brightnessctl set 10%-
    fi
    ;;
  *)
    echo "usage: $0 vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down" >&2
    exit 1
    ;;
esac
