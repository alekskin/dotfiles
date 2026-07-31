#!/bin/bash
# Poll battery via upower; notify on low / critical (once per threshold).
# Started from sway; runs until killed.

set -u

INTERVAL=60
LOW=20
CRITICAL=10
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/sway-battery"
mkdir -p "$STATE_DIR"

notify_once() {
  local key=$1
  shift
  local flag="$STATE_DIR/$key"
  [[ -f "$flag" ]] && return 0
  notify-send "$@"
  touch "$flag"
}

clear_flag() {
  rm -f "$STATE_DIR/$1"
}

while true; do
  # Prefer BAT0/BAT1 sysfs (simple, no jq)
  pct=""
  status=""
  for bat in /sys/class/power_supply/BAT*; do
    [[ -d "$bat" ]] || continue
    if [[ -f "$bat/capacity" ]]; then
      pct=$(cat "$bat/capacity" 2>/dev/null || true)
      status=$(cat "$bat/status" 2>/dev/null || true)
      break
    fi
  done

  if [[ -z "${pct:-}" ]]; then
    sleep "$INTERVAL"
    continue
  fi

  if [[ "$status" == "Charging" || "$status" == "Full" || "$status" == "Not charging" ]]; then
    clear_flag low
    clear_flag critical
  else
    if (( pct <= CRITICAL )); then
      notify_once critical -u critical "Battery critical" "${pct}% remaining — plug in soon"
    elif (( pct <= LOW )); then
      notify_once low -u normal "Battery low" "${pct}% remaining"
    else
      clear_flag low
      clear_flag critical
    fi
  fi

  sleep "$INTERVAL"
done
