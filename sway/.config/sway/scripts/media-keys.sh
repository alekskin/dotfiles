#!/bin/bash
# Volume / brightness keys. The on-screen readout is a notification: one
# replaceable bubble carrying a `value` hint, which mako draws as a progress
# bar (see the [app-name=osd] block in mako/config). This replaces swayosd,
# whose GTK popup ignored the session's theme.
#
# Usage: media-keys.sh vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down
#                      |kbd-up|kbd-down

set -u

VOL_STEP=5
BRIGHT_STEP=10
# The Mac's keyboard backlight is an LED device, not a backlight one, so it
# needs naming explicitly; brightnessctl's default device is the screen.
KBD_DEV="smc::kbd_backlight"
SINK="@DEFAULT_AUDIO_SINK@"
SOURCE="@DEFAULT_AUDIO_SOURCE@"

# Same tag for every reading, so holding a key updates one bubble in place
# instead of stacking a column of them.
osd() {
  local glyph=$1 label=$2 value=${3:-}
  local args=(-a osd -h "string:x-canonical-private-synchronous:osd")
  [[ -n $value ]] && args+=(-h "int:value:$value")
  notify-send "${args[@]}" "$glyph  $label" 2>/dev/null || true
}

# "Volume: 0.50" / "Volume: 0.50 [MUTED]" -> percent, and mute state via rc.
read_volume() {
  local out
  out=$(wpctl get-volume "$1" 2>/dev/null) || return 2
  awk '{printf "%.0f\n", $2 * 100}' <<<"$out"
  [[ $out == *"[MUTED]"* ]] && return 1
  return 0
}

vol_glyph() {
  local pct=$1 muted=$2
  if ((muted)); then echo "󰝟"
  elif ((pct == 0)); then echo "󰕿"
  elif ((pct < 34)); then echo "󰕿"
  elif ((pct < 67)); then echo "󰖀"
  else echo "󰕾"
  fi
}

show_volume() {
  local pct muted=0
  pct=$(read_volume "$SINK") || muted=1
  [[ -z $pct ]] && return
  if ((muted)); then
    osd "$(vol_glyph "$pct" 1)" "Muted" 0
  else
    osd "$(vol_glyph "$pct" 0)" "$pct%" "$pct"
  fi
}

show_mic() {
  local pct muted=0
  pct=$(read_volume "$SOURCE") || muted=1
  ((muted)) && osd "󰍭" "Mic muted" || osd "󰍬" "Mic on"
}

show_brightness() {
  local pct glyph
  pct=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
  [[ -z $pct ]] && return
  if ((pct < 34)); then glyph="󰃞"
  elif ((pct < 67)); then glyph="󰃟"
  else glyph="󰃠"
  fi
  osd "$glyph" "$pct%" "$pct"
}

show_kbd() {
  local pct glyph
  pct=$(brightnessctl -m -d "$KBD_DEV" 2>/dev/null | cut -d, -f4 | tr -d '%')
  [[ -z $pct ]] && return
  # Off is worth its own glyph: at 0% the key otherwise looks like it did
  # nothing at all.
  if ((pct == 0)); then glyph="󰌌"; else glyph="󰥻"; fi
  osd "$glyph" "Keyboard $pct%" "$pct"
}

case "${1:-}" in
  vol-up)
    # -l caps the boost: without it wpctl walks past 100% into distortion.
    wpctl set-mute "$SINK" 0 2>/dev/null
    wpctl set-volume -l 1.0 "$SINK" "${VOL_STEP}%+"
    show_volume
    ;;
  vol-down)
    wpctl set-volume -l 1.0 "$SINK" "${VOL_STEP}%-"
    show_volume
    ;;
  vol-mute)
    wpctl set-mute "$SINK" toggle
    show_volume
    ;;
  mic-mute)
    wpctl set-mute "$SOURCE" toggle
    show_mic
    ;;
  bright-up)
    brightnessctl set "${BRIGHT_STEP}%+" >/dev/null
    show_brightness
    ;;
  bright-down)
    brightnessctl set "${BRIGHT_STEP}%-" >/dev/null
    show_brightness
    ;;
  kbd-up)
    brightnessctl -d "$KBD_DEV" set "${BRIGHT_STEP}%+" >/dev/null 2>&1
    show_kbd
    ;;
  kbd-down)
    brightnessctl -d "$KBD_DEV" set "${BRIGHT_STEP}%-" >/dev/null 2>&1
    show_kbd
    ;;
  *)
    echo "usage: $0 vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down|kbd-up|kbd-down" >&2
    exit 1
    ;;
esac
