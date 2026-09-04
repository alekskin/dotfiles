#!/bin/bash
# Battery snapshot for waybar (left-click). Power menu stays on right-click
# and Super+Ctrl+P / the power key.

set -u
S="$HOME/.config/sway/scripts"

bat=$(upower -e 2>/dev/null | grep -i bat | head -1 || true)
if [[ -z "${bat:-}" ]]; then
  notify-send "Battery" "No battery device" 2>/dev/null || true
  exit 0
fi

info=$(upower -i "$bat" 2>/dev/null)

field() {
  awk -F: -v key="$1" '
    BEGIN { key = tolower(key) }
    {
      k = $1
      gsub(/^[ \t]+|[ \t]+$/, "", k)
      if (tolower(k) == key) {
        v = substr($0, index($0, ":") + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        print v
        exit
      }
    }
  ' <<<"$info"
}

int_part() {
  local x=${1%% *}
  x=${x%%%*}
  printf '%s' "${x%%.*}"
}

state=$(field state)
pct=$(int_part "$(field percentage)")
rate=$(int_part "$(field energy-rate)")
temp=$(int_part "$(field temperature)")
cycles=$(field charge-cycles)
health=$(int_part "$(field capacity)")
vendor=$(field vendor)
model=$(field model)
full=$(field energy-full)
ttf=$(field "time to full")
tte=$(field "time to empty")

profile=$("$S/power-profile.sh" get 2>/dev/null || true)
profile=${profile:-unknown}

online=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 0)
if [[ "$online" == 1 ]]; then
  ac="AC plugged in"
else
  ac="On battery"
fi

case "$state" in
  charging)      head="Charging · ${pct}%" ;;
  discharging)   head="Discharging · ${pct}%" ;;
  fully-charged) head="Full · ${pct}%" ;;
  *)             head="${state:-Unknown} · ${pct}%" ;;
esac

lines=("$head" "$ac")

case "$state" in
  charging)
    if [[ -n "$ttf" ]]; then
      lines+=("${rate} W in · ${ttf} to full")
    else
      lines+=("${rate} W in")
    fi
    ;;
  discharging)
    if [[ -n "$tte" ]]; then
      lines+=("${rate} W out · ${tte} left")
    else
      lines+=("${rate} W out")
    fi
    ;;
  *)
    [[ -n "$rate" && "$rate" != "0" ]] && lines+=("${rate} W")
    ;;
esac

detail=""
[[ -n "$temp" ]] && detail+="${temp}°C"
if [[ -n "$cycles" && "$cycles" != "-" ]]; then
  [[ -n "$detail" ]] && detail+=" · "
  detail+="${cycles} cycles"
fi
if [[ -n "$health" ]]; then
  [[ -n "$detail" ]] && detail+=" · "
  detail+="health ${health}%"
fi
[[ -n "$detail" ]] && lines+=("$detail")

pack=""
[[ -n "$vendor" ]] && pack="$vendor"
[[ -n "$model" ]] && pack="${pack:+$pack }$model"
if [[ -n "$full" ]]; then
  fw=${full%% *}
  fw=${fw%%.*}
  pack="${pack:+$pack · }${fw} Wh"
fi
[[ -n "$pack" ]] && lines+=("$pack")

lines+=("Profile: ${profile}")
lines+=("────────")
lines+=("󰓅  Cycle power profile")
lines+=("  Power menu")

chosen=$(
  printf '%s\n' "${lines[@]}" \
    | "$S/wofi.sh" --dmenu --prompt "Battery" --width 420 --height 280 --cache-file /dev/null \
    || true
)

case "$chosen" in
  *"power profile"*) "$S/power-profile.sh" cycle ;;
  *"Power menu"*)    "$S/power-menu.sh" ;;
esac
