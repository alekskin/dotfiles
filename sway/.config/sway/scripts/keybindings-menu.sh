#!/bin/bash
# Human-readable keybinding cheatsheet (Super+Ctrl+K).

set -u

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config"
[[ -f "$cfg" ]] || cfg="$HOME/.config/sway/config"

list=$(
  python3 - "$cfg" <<'PY'
import re
import sys
import os

cfg_path = sys.argv[1]
with open(cfg_path, encoding="utf-8") as f:
    lines = f.readlines()


def expand_key(k: str) -> str:
    for a, b in [
        ("$mod", "Super"),
        ("Mod1", "Alt"),
        ("Mod4", "Super"),
        ("$left", "h"),
        ("$down", "j"),
        ("$up", "k"),
        ("$right", "l"),
        ("XF86AudioRaiseVolume", "Vol+"),
        ("XF86AudioLowerVolume", "Vol-"),
        ("XF86AudioMute", "Mute"),
        ("XF86AudioMicMute", "Mic mute"),
        ("XF86AudioPlay", "Play"),
        ("XF86AudioPause", "Pause"),
        ("XF86AudioNext", "Next"),
        ("XF86AudioPrev", "Prev"),
        ("XF86MonBrightnessUp", "Brightness+"),
        ("XF86MonBrightnessDown", "Brightness-"),
        ("XF86KbdBrightnessUp", "Kbd light+"),
        ("XF86KbdBrightnessDown", "Kbd light-"),
        ("XF86PowerOff", "Power"),
    ]:
        k = k.replace(a, b)
    return k


SCRIPT_LABELS = {
    "power-menu.sh": "Power menu (suspend / reboot / off)",
    "clipboard-menu.sh": "Clipboard history",
    "capture-menu.sh": "Capture menu (screenshot / record)",
    "system-menu.sh": "System menu",
    "keybindings-menu.sh": "Show keybindings",
    "share-menu.sh": "Share menu (LocalSend, folders)",
    "lock.sh": "Lock screen",
    "toggle-idle.sh": "Toggle idle lock",
    "idle-menu.sh": "Idle timeouts menu",
    "toggle-notifications.sh": "Toggle do-not-disturb",
    "toggle-nightlight.sh": "Toggle night light",
    "power-profile.sh": "Cycle power profile",
    "screenrecord.sh": "Screen recording",
    "screenshot.sh": "Take screenshot",
    "lid.sh": "Laptop lid handler",
}


def describe(action: str) -> str:
    # Scripts (with args)
    m = re.search(r"scripts/([a-z0-9_-]+\.sh)(.*)$", action)
    if m:
        script, rest = m.group(1), m.group(2)
        if script == "media-keys.sh":
            return {
                "vol-up": "Volume up",
                "vol-down": "Volume down",
                "vol-mute": "Mute audio",
                "mic-mute": "Mute microphone",
                "bright-up": "Brightness up",
                "bright-down": "Brightness down",
            }.get(rest.strip().split()[-1] if rest.strip() else "", "Media key")
        if script in SCRIPT_LABELS:
            return SCRIPT_LABELS[script]
        return script.removesuffix(".sh").replace("-", " ").capitalize()

    # Built-in / common commands (order matters)
    patterns = [
        (r"^exec \$term\b", "Open terminal"),
        (r"^exec \$menu\b", "App launcher"),
        (r"^kill$", "Close window"),
        (r"^reload$", "Reload sway config"),
        (r"^floating toggle$", "Toggle floating"),
        (r"^focus mode_toggle$", "Toggle focus tiling/floating"),
        (r"^focus parent$", "Focus parent"),
        (r"^focus left$", "Focus left"),
        (r"^focus right$", "Focus right"),
        (r"^focus up$", "Focus up"),
        (r"^focus down$", "Focus down"),
        (r"^move left$", "Move window left"),
        (r"^move right$", "Move window right"),
        (r"^move up$", "Move window up"),
        (r"^move down$", "Move window down"),
        (r"^splith$", "Split horizontal"),
        (r"^splitv$", "Split vertical"),
        (r"^layout stacking$", "Stacking layout"),
        (r"^layout tabbed$", "Tabbed layout"),
        (r"^layout toggle split$", "Toggle split layout"),
        (r"^fullscreen", "Fullscreen"),
        (r"^workspace number (\d+)$", "Switch to workspace \\1"),
        (r"^move container to workspace number (\d+)$", "Move window to workspace \\1"),
        (r"^move scratchpad$", "Send to scratchpad"),
        (r"^scratchpad show$", "Show scratchpad"),
        (r'^mode "resize"$', "Enter resize mode"),
        (r'^mode "default"$', "Leave mode"),
        (r"swaynag.*exit", "Exit sway"),
        (r"bluetui", "Bluetooth (bluetui)"),
        (r"impala", "Wi‑Fi (impala)"),
        (r"\bthunar\b", "File manager"),
        (r"makoctl dismiss --all", "Dismiss all notifications"),
        (r"makoctl dismiss", "Dismiss last notification"),
        (r"makoctl invoke", "Invoke notification action"),
        (r"makoctl restore", "Restore last notification"),
        (r"playerctl play-pause", "Play / pause"),
        (r"playerctl next", "Next track"),
        (r"playerctl previous", "Previous track"),
        (r"wtype.*ctrl.*Insert", "Copy (universal)"),
        (r"wtype.*shift.*Insert", "Paste (universal)"),
        (r"wtype.*-k x", "Cut (universal)"),
        (r"kbd_backlight.*10%\+", "Keyboard backlight up"),
        (r"kbd_backlight.*10%-", "Keyboard backlight down"),
    ]
    for pat, label in patterns:
        m = re.search(pat, action)
        if m:
            return m.expand(label) if "\\" in label else label

    a = action[5:] if action.startswith("exec ") else action
    home = os.environ.get("HOME", "")
    if home:
        a = a.replace(home, "~")
    a = a.replace(os.path.expanduser("~"), "~")
    return a[:90]


rows = []
seen_desc_action = set()
in_resize = False

for raw in lines:
    stripped = raw.strip()

    if stripped.startswith("mode ") and "resize" in stripped:
        in_resize = True
        continue
    if in_resize:
        if stripped == "}":
            in_resize = False
        continue

    if not stripped.startswith("bindsym"):
        continue

    rest = stripped[len("bindsym") :].strip()
    parts = rest.split()
    while parts and parts[0].startswith("--"):
        parts.pop(0)
    if len(parts) < 2:
        continue

    key, action = parts[0], " ".join(parts[1:])
    pkey = expand_key(key)
    desc = describe(action)

    # Drop arrow-key duplicates of vim-key binds (same action)
    if (desc, action) in seen_desc_action and any(
        x in pkey for x in ("Left", "Right", "Up", "Down")
    ):
        continue
    seen_desc_action.add((desc, action))
    rows.append((pkey, desc))


def sort_key(row):
    k = row[0]
    if k.startswith("Super"):
        return (0, k.lower())
    if k[0:3] in ("Ctr", "Alt"):
        return (1, k.lower())
    return (2, k.lower())


rows.sort(key=sort_key)
for k, d in rows:
    print(f"{k:<32}  {d}")
PY
)

[[ -z "${list:-}" ]] && {
  notify-send "Keybindings" "No bindsym lines found" 2>/dev/null || true
  exit 0
}

printf '%s\n' "$list" \
  | wofi --dmenu --prompt "Keybindings" --width 640 --height 520 --cache-file /dev/null \
  >/dev/null || true
