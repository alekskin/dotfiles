#!/bin/bash
# Start swayidle from idle.conf. Safe to re-run (replaces previous instance).

set -u

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/sway/idle.conf"
SCRIPTS="${HOME}/.config/sway/scripts"
LOCK_SH="${SCRIPTS}/lock.sh"
DIM_SH="${SCRIPTS}/brightness-dim.sh"
RESTORE_SH="${SCRIPTS}/brightness-restore.sh"

# Defaults (Omarchy-like)
DIM_SEC=120
DIM_PERCENT=15
LOCK_SEC=150
BLANK_SEC=153
SUSPEND_SEC=0

if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF"
fi

is_num() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

is_num "$DIM_SEC" || DIM_SEC=0
is_num "$LOCK_SEC" || LOCK_SEC=0
is_num "$BLANK_SEC" || BLANK_SEC=0
is_num "$SUSPEND_SEC" || SUSPEND_SEC=0
is_num "$DIM_PERCENT" || DIM_PERCENT=15

pkill -x swayidle 2>/dev/null || true
sleep 0.1

if (( LOCK_SEC == 0 && BLANK_SEC == 0 && DIM_SEC == 0 && SUSPEND_SEC == 0 )); then
  exit 0
fi

args=(-w)

# Dim: save real brightness, set low %. Resume always goes through restore helper
# (power on + restore) so we don't stay stuck dim after unlock/sleep.
if (( DIM_SEC > 0 )) && command -v brightnessctl >/dev/null; then
  # Quote carefully: swayidle runs via sh -c
  args+=(
    timeout "$DIM_SEC"
    "$DIM_SH $DIM_PERCENT"
    resume "$RESTORE_SH"
  )
fi

if (( LOCK_SEC > 0 )); then
  args+=(
    timeout "$LOCK_SEC"
    "$LOCK_SH"
  )
fi

if (( BLANK_SEC > 0 )); then
  args+=(
    timeout "$BLANK_SEC"
    'swaymsg "output * power off"'
    resume "$RESTORE_SH"
  )
fi

if (( SUSPEND_SEC > 0 )); then
  args+=(
    timeout "$SUSPEND_SEC"
    "systemctl suspend"
  )
fi

# Lock before sleep; on wake restore brightness (after-resume)
args+=(
  before-sleep "$LOCK_SH"
  after-resume "$RESTORE_SH"
)

exec swayidle "${args[@]}"
