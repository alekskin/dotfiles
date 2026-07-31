#!/bin/bash
# Interactive idle settings (wofi) — no need to hand-edit idle.conf for common tweaks.

set -u

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/sway/idle.conf"
mkdir -p "$(dirname "$CONF")"

# Load current
DIM_SEC=120
DIM_PERCENT=15
LOCK_SEC=150
BLANK_SEC=153
SUSPEND_SEC=0
[[ -f "$CONF" ]] && source "$CONF"

fmt_sec() {
  local s=$1
  if (( s == 0 )); then
    echo "off"
  elif (( s < 60 )); then
    echo "${s}s"
  elif (( s % 60 == 0 )); then
    echo "$((s / 60))m"
  else
    echo "$((s / 60))m $((s % 60))s"
  fi
}

status="dim $(fmt_sec "$DIM_SEC") · lock $(fmt_sec "$LOCK_SEC") · blank $(fmt_sec "$BLANK_SEC") · suspend $(fmt_sec "$SUSPEND_SEC")"
if pgrep -x swayidle >/dev/null; then
  status="ON · $status"
else
  status="OFF · $status"
fi

choice=$(
  printf '%s\n' \
    "── $status ──" \
    "Preset: Omarchy-like (dim 2m · lock 2.5m · blank ~2.5m · no suspend)" \
    "Preset: Short (dim 1m · lock 2m · blank 2.5m · no suspend)" \
    "Preset: Relaxed (dim 5m · lock 10m · blank 12m · no suspend)" \
    "Preset: Suspend after 20m (lock 5m · blank 6m · suspend 20m)" \
    "Preset: Never (disable all idle actions)" \
    "Toggle idle daemon on/off" \
    "Lock now" \
    "Set lock timeout…" \
    "Set dim timeout…" \
    "Set blank timeout…" \
    "Set suspend timeout…" \
    | wofi --dmenu --prompt "Idle" --width 560 --height 420 --cache-file /dev/null || true
)

[[ -z "${choice:-}" || "$choice" == ──* ]] && exit 0

write_conf() {
  cat >"$CONF" <<EOF
# Idle / lock timeouts (seconds). 0 = disabled.
# Managed by idle-menu.sh (Super+Ctrl+Shift+I). You can still edit this file.

DIM_SEC=${DIM_SEC}
DIM_PERCENT=${DIM_PERCENT}
LOCK_SEC=${LOCK_SEC}
BLANK_SEC=${BLANK_SEC}
SUSPEND_SEC=${SUSPEND_SEC}
EOF
}

restart_if_on() {
  if pgrep -x swayidle >/dev/null || [[ "${1:-}" == force ]]; then
    ~/.config/sway/scripts/idle-daemon.sh &
    disown
  fi
}

pick_timeout() {
  local title=$1 current=$2
  local picked
  picked=$(
    printf '%s\n' \
      "off (0)" \
      "30 seconds" \
      "1 minute" \
      "2 minutes" \
      "2.5 minutes" \
      "5 minutes" \
      "10 minutes" \
      "15 minutes" \
      "20 minutes" \
      "30 minutes" \
      "45 minutes" \
      "60 minutes" \
      | wofi --dmenu --prompt "$title (now $(fmt_sec "$current"))" --width 360 --height 400 --cache-file /dev/null || true
  )
  case "$picked" in
    "off (0)"|"") echo 0 ;;
    "30 seconds") echo 30 ;;
    "1 minute") echo 60 ;;
    "2 minutes") echo 120 ;;
    "2.5 minutes") echo 150 ;;
    "5 minutes") echo 300 ;;
    "10 minutes") echo 600 ;;
    "15 minutes") echo 900 ;;
    "20 minutes") echo 1200 ;;
    "30 minutes") echo 1800 ;;
    "45 minutes") echo 2700 ;;
    "60 minutes") echo 3600 ;;
    *) echo "$current" ;;
  esac
}

case "$choice" in
  "Preset: Omarchy-like"*)
    DIM_SEC=120; DIM_PERCENT=15; LOCK_SEC=150; BLANK_SEC=153; SUSPEND_SEC=0
    write_conf; restart_if_on force
    notify-send -u low "Idle" "Omarchy-like: lock ~2.5m" 2>/dev/null || true
    ;;
  "Preset: Short"*)
    DIM_SEC=60; DIM_PERCENT=15; LOCK_SEC=120; BLANK_SEC=150; SUSPEND_SEC=0
    write_conf; restart_if_on force
    notify-send -u low "Idle" "Short timeouts" 2>/dev/null || true
    ;;
  "Preset: Relaxed"*)
    DIM_SEC=300; DIM_PERCENT=20; LOCK_SEC=600; BLANK_SEC=720; SUSPEND_SEC=0
    write_conf; restart_if_on force
    notify-send -u low "Idle" "Relaxed timeouts" 2>/dev/null || true
    ;;
  "Preset: Suspend"*)
    DIM_SEC=240; DIM_PERCENT=15; LOCK_SEC=300; BLANK_SEC=360; SUSPEND_SEC=1200
    write_conf; restart_if_on force
    notify-send -u low "Idle" "Suspend after 20m" 2>/dev/null || true
    ;;
  "Preset: Never"*)
    DIM_SEC=0; LOCK_SEC=0; BLANK_SEC=0; SUSPEND_SEC=0
    write_conf
    pkill -x swayidle 2>/dev/null || true
    notify-send -u low "Idle" "All idle actions off" 2>/dev/null || true
    ;;
  "Toggle idle"*)
    ~/.config/sway/scripts/toggle-idle.sh
    ;;
  "Lock now")
    ~/.config/sway/scripts/lock.sh
    ;;
  "Set lock timeout"*)
    LOCK_SEC=$(pick_timeout "Lock after" "$LOCK_SEC")
    # Keep blank slightly after lock if both enabled
    if (( LOCK_SEC > 0 && (BLANK_SEC == 0 || BLANK_SEC <= LOCK_SEC) )); then
      BLANK_SEC=$((LOCK_SEC + 3))
    fi
    write_conf; restart_if_on force
    notify-send -u low "Idle" "Lock after $(fmt_sec "$LOCK_SEC")" 2>/dev/null || true
    ;;
  "Set dim timeout"*)
    DIM_SEC=$(pick_timeout "Dim after" "$DIM_SEC")
    write_conf; restart_if_on force
    notify-send -u low "Idle" "Dim after $(fmt_sec "$DIM_SEC")" 2>/dev/null || true
    ;;
  "Set blank timeout"*)
    BLANK_SEC=$(pick_timeout "Blank after" "$BLANK_SEC")
    write_conf; restart_if_on force
    notify-send -u low "Idle" "Blank after $(fmt_sec "$BLANK_SEC")" 2>/dev/null || true
    ;;
  "Set suspend timeout"*)
    SUSPEND_SEC=$(pick_timeout "Suspend after" "$SUSPEND_SEC")
    write_conf; restart_if_on force
    notify-send -u low "Idle" "Suspend after $(fmt_sec "$SUSPEND_SEC")" 2>/dev/null || true
    ;;
esac
