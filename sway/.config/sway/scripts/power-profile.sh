#!/bin/bash
# Cycle or set power-profiles-daemon profile via D-Bus (no PyGObject required).
# powerprofilesctl needs python-gobject; on minimal installs it crashes and our
# old cycle logic always announced "performance".

set -u

DEST="org.freedesktop.UPower.PowerProfiles"
PATH_OBJ="/org/freedesktop/UPower/PowerProfiles"
IFACE="org.freedesktop.UPower.PowerProfiles"

get_profile() {
  # busctl → s "balanced"
  busctl get-property "$DEST" "$PATH_OBJ" "$IFACE" ActiveProfile 2>/dev/null \
    | awk -F'"' '{print $2}'
}

# ppd owns the profile *name*, but on hardware without HWP or an ACPI platform
# profile it has no knob to turn (see system/usr/local/bin/cpu-power-profile).
# The helper does the actual CPU tuning; skip it silently where it isn't
# installed, so the script still works on a machine ppd can drive by itself.
CPU_HELPER=/usr/local/bin/cpu-power-profile

apply_cpu() {
  local profile=$1
  [[ -x "$CPU_HELPER" ]] || return 0
  if ! pkexec "$CPU_HELPER" "$profile" >/dev/null 2>&1; then
    notify-send -u critical "Power" \
      "CPU tuning failed for $profile" 2>/dev/null || true
  fi
}

set_profile() {
  local profile=$1
  # variant string: s "name"
  busctl set-property "$DEST" "$PATH_OBJ" "$IFACE" ActiveProfile s "$profile" 2>/dev/null \
    || return 1
  apply_cpu "$profile"
}

list_profiles() {
  # Prefer Profiles property; fall back to the usual three
  local raw
  raw=$(busctl get-property "$DEST" "$PATH_OBJ" "$IFACE" Profiles 2>/dev/null || true)
  if [[ -n "$raw" ]]; then
    # Format: "Profile" s "power-saver" ...
    grep -oE '"Profile" s "[^"]+"' <<<"$raw" 2>/dev/null \
      | sed -E 's/.*"Profile" s "([^"]+)"/\1/' \
      || true
  fi
}

action=${1:-cycle}
shift 2>/dev/null || true

quiet=0
wait_for=0
while (($#)); do
  case $1 in
    --quiet) quiet=1 ;;
    --wait)
      wait_for=${2:-0}
      shift
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# power-profiles-daemon is ordered After=multi-user.target, so on a machine
# where something slow sits on that target -- docker restoring containers here
# costs two minutes -- it is simply not on the bus yet when the session starts.
# D-Bus activation cannot jump the queue either, since it starts the same
# ordered unit. So the login path waits instead of announcing a failure the
# user can do nothing about, while an interactive call still reports at once.
wait_for_daemon() {
  local deadline=$((SECONDS + wait_for))
  while :; do
    busctl status "$DEST" &>/dev/null && return 0
    ((SECONDS >= deadline)) && return 1
    sleep 2
  done
}

if ! wait_for_daemon; then
  ((quiet)) || notify-send -u critical "Power" \
    "power-profiles-daemon is not running" 2>/dev/null || true
  exit 1
fi

case "$action" in
  get)
    get_profile
    ;;
  list)
    list_profiles
    ;;
  cycle)
    cur=$(get_profile)
    if [[ -z "$cur" ]]; then
      notify-send -u critical "Power" "Could not read ActiveProfile" 2>/dev/null || true
      exit 1
    fi

    # Build cycle from available profiles if possible
    mapfile -t available < <(list_profiles)
    if ((${#available[@]} == 0)); then
      available=(power-saver balanced performance)
    fi

    next="${available[0]}"
    for i in "${!available[@]}"; do
      if [[ "${available[$i]}" == "$cur" ]]; then
        next="${available[$(( (i + 1) % ${#available[@]} ))]}"
        break
      fi
    done

    if ! set_profile "$next"; then
      notify-send -u critical "Power" "Failed to set profile: $next" 2>/dev/null || true
      exit 1
    fi

    # Confirm
    now=$(get_profile)
    notify-send -u low "Power profile" "${now:-$next}" 2>/dev/null || true
    ;;
  power-saver|balanced|performance)
    if ! set_profile "$action"; then
      ((quiet)) || notify-send -u critical "Power" \
        "Failed to set profile: $action" 2>/dev/null || true
      exit 1
    fi
    # --quiet is for the login default: announcing a profile nobody chose is
    # just noise, and mako may not even be up yet.
    if ((!quiet)); then
      now=$(get_profile)
      notify-send -u low "Power profile" "${now:-$action}" 2>/dev/null || true
    fi
    ;;
  *)
    echo "usage: $0 [cycle|get|list|power-saver|balanced|performance] [--quiet] [--wait SECONDS]" >&2
    exit 1
    ;;
esac
