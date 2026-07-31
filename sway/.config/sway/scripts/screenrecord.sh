#!/bin/bash
# Toggle screen recording with wf-recorder (Omarchy-style start/stop).
# Usage: screenrecord.sh [region|full] [--audio]
# If already recording, any invocation stops and saves.

set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/sway-screenrecord-filename"
mode="region"
with_audio=false

for arg in "$@"; do
  case "$arg" in
    region|full) mode="$arg" ;;
    --audio) with_audio=true ;;
  esac
done

need() {
  if ! command -v "$1" >/dev/null; then
    notify-send "Screen record" "Missing package providing: $1" -u critical 2>/dev/null || true
    exit 1
  fi
}

recording_active() {
  pgrep -x wf-recorder >/dev/null 2>&1
}

# Nudge waybar custom/screenrecord module immediately
refresh_waybar() {
  pkill -RTMIN+8 waybar 2>/dev/null || true
}

stop_recording() {
  need notify-send
  pkill -INT -x wf-recorder 2>/dev/null || true

  # Wait up to ~5s for a clean stop (SIGINT finalizes the file)
  local count=0
  while recording_active && ((count < 50)); do
    sleep 0.1
    count=$((count + 1))
  done

  if recording_active; then
    pkill -9 -x wf-recorder 2>/dev/null || true
    notify-send "Screen recording" "Force-stopped; file may be incomplete" -u critical -t 4000
  else
    local filename
    filename=$(cat "$STATE_FILE" 2>/dev/null || true)
    if [[ -n "${filename:-}" && -f "$filename" ]]; then
      notify-send "Screen recording saved" "$filename" -t 5000
    else
      notify-send "Screen recording stopped" -t 2500
    fi
  fi
  rm -f "$STATE_FILE"
  refresh_waybar
}

start_recording() {
  need wf-recorder
  need notify-send

  local outdir="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
  mkdir -p "$outdir"
  local filename="$outdir/screenrecording-$(date +'%Y-%m-%d_%H-%M-%S').mp4"

  local -a args=(-f "$filename")
  $with_audio && args+=(-a)

  case "$mode" in
    full)
      if command -v swaymsg >/dev/null && command -v jq >/dev/null; then
        local output
        output=$(swaymsg -t get_outputs -r | jq -r '.[] | select(.focused == true) | .name')
        if [[ -n "${output:-}" && "$output" != "null" ]]; then
          args+=(-o "$output")
        fi
      fi
      ;;
    region|*)
      need slurp
      local geo
      geo=$(slurp 2>/dev/null) || exit 0
      [[ -z "${geo:-}" ]] && exit 0
      args+=(-g "$geo")
      ;;
  esac

  echo "$filename" >"$STATE_FILE"
  # shellcheck disable=SC2086
  wf-recorder "${args[@]}" >/dev/null 2>&1 &

  # Confirm process is up
  sleep 0.3
  if recording_active; then
    local audio_note=""
    $with_audio && audio_note=" (with audio)"
    notify-send "Screen recording$audio_note" "Recording… click  in waybar or Super+Ctrl+C to stop" -t 3000
    refresh_waybar
  else
    rm -f "$STATE_FILE"
    notify-send "Screen recording failed" "wf-recorder did not start" -u critical -t 4000
    refresh_waybar
    exit 1
  fi
}

if recording_active; then
  stop_recording
else
  start_recording
fi
