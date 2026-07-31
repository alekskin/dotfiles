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

set_profile() {
  local profile=$1
  # variant string: s "name"
  busctl set-property "$DEST" "$PATH_OBJ" "$IFACE" ActiveProfile s "$profile" 2>/dev/null
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

if ! busctl status "$DEST" &>/dev/null; then
  notify-send -u critical "Power" \
    "power-profiles-daemon is not running" 2>/dev/null || true
  exit 1
fi

case "${1:-cycle}" in
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
    if ! set_profile "$1"; then
      notify-send -u critical "Power" "Failed to set profile: $1" 2>/dev/null || true
      exit 1
    fi
    now=$(get_profile)
    notify-send -u low "Power profile" "${now:-$1}" 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 [cycle|get|list|power-saver|balanced|performance]" >&2
    exit 1
    ;;
esac
