#!/bin/bash
# Toggle night light (warm gamma via wlsunset).
#
# Important: do NOT use lat/lon sun scheduling for a toggle.
# During the day that keeps 6500K, so "on" looks identical to "off".
# We force a constant warm temperature while enabled.

set -u

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/sway-nightlight"
LOG="${XDG_RUNTIME_DIR:-/tmp}/wlsunset-nightlight.log"
mkdir -p "$(dirname "$STATE")"

# Lower = warmer. 3200K is clearly orange; override with NIGHTLIGHT_TEMP=3500 etc.
TEMP="${NIGHTLIGHT_TEMP:-3200}"

start_nightlight() {
  if ! command -v wlsunset >/dev/null; then
    notify-send -u critical "Night light" "Install wlsunset" 2>/dev/null || true
    return 1
  fi

  pkill -x wlsunset 2>/dev/null || true
  sleep 0.15

  # wlsunset requires high > low; keep them 1K apart for a constant tint
  local high=$((TEMP + 1))
  : >"$LOG"
  wlsunset -t "$TEMP" -T "$high" >"$LOG" 2>&1 &
  disown

  sleep 0.35
  if ! pgrep -x wlsunset >/dev/null; then
    echo off >"$STATE"
    notify-send -u critical "Night light" "wlsunset exited — see $LOG" 2>/dev/null || true
    return 1
  fi

  if grep -qi 'gamma control.*failed' "$LOG" 2>/dev/null; then
    # Still running but compositor rejected gamma (some panels/drivers)
    notify-send -u critical "Night light" \
      "Gamma control failed on this display (driver may not support it)" 2>/dev/null || true
    echo on >"$STATE"
    return 1
  fi

  echo on >"$STATE"
  notify-send -u low "󰔎  Night light on" "${TEMP}K — should look warmer" 2>/dev/null || true
}

stop_nightlight() {
  pkill -x wlsunset 2>/dev/null || true
  sleep 0.1
  # Apply neutral temp briefly so the ramp resets after the client exits
  if command -v wlsunset >/dev/null; then
    wlsunset -t 6500 -T 6501 >/dev/null 2>&1 &
    local pid=$!
    sleep 0.25
    kill "$pid" 2>/dev/null || true
    pkill -x wlsunset 2>/dev/null || true
  fi
  echo off >"$STATE"
  notify-send -u low "󰔎  Night light off" 2>/dev/null || true
}

if pgrep -x wlsunset >/dev/null; then
  stop_nightlight
else
  start_nightlight
fi
