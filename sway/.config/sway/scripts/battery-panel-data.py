#!/usr/bin/env python3
"""JSON snapshot for the Quickshell battery panel."""

from __future__ import annotations

import json
import os
import subprocess
import time


def _read(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return None


def _bat_path() -> str | None:
    base = "/sys/class/power_supply"
    try:
        names = sorted(os.listdir(base))
    except OSError:
        return None
    for name in names:
        p = os.path.join(base, name)
        if not name.startswith("BAT"):
            continue
        if _read(os.path.join(p, "type")) == "Battery":
            return p
    return None


def _upower_path() -> str | None:
    try:
        out = subprocess.check_output(["upower", "-e"], text=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    for line in out.splitlines():
        line = line.strip()
        if "battery" in line.lower() and "DisplayDevice" not in line:
            return line
    return None


def _int(s: str | None) -> int | None:
    if not s:
        return None
    try:
        return int(float(s.split()[0].replace("%", "")))
    except ValueError:
        return None


def _float(s: str | None) -> float | None:
    if not s:
        return None
    try:
        return float(s.split()[0].replace("%", ""))
    except ValueError:
        return None


def _fmt_dur(sec: float | None) -> str | None:
    if sec is None or sec < 0:
        return None
    sec = int(sec)
    if sec < 45:
        return "just now" if sec < 15 else f"{sec}s"
    minutes, _ = divmod(sec, 60)
    hours, minutes = divmod(minutes, 60)
    days, hours = divmod(hours, 24)
    if days:
        return f"{days}d {hours}h" if hours else f"{days}d"
    if hours:
        return f"{hours}h {minutes}m" if minutes else f"{hours}h"
    return f"{minutes}m"


def _fmt_eta(sec: float | None) -> str | None:
    if not sec or sec <= 0:
        return None
    sec = int(sec)
    minutes, _ = divmod(sec, 60)
    hours, minutes = divmod(minutes, 60)
    if hours >= 10:
        return f"{hours}h"
    if hours:
        return f"{hours}h {minutes}m" if minutes else f"{hours}h"
    if minutes:
        return f"{minutes}m"
    return "<1m"


def _upower_info(path: str) -> dict[str, str]:
    info: dict[str, str] = {}
    try:
        raw = subprocess.check_output(["upower", "-i", path], text=True)
    except (OSError, subprocess.CalledProcessError):
        return info
    for line in raw.splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        k, v = k.strip().lower(), v.strip()
        if k and k not in info:
            info[k] = v
    return info


def _history(path: str) -> list[tuple[int, float, int]]:
    try:
        raw = subprocess.check_output(
            [
                "busctl",
                "call",
                "org.freedesktop.UPower",
                path,
                "org.freedesktop.UPower.Device",
                "GetHistory",
                "suu",
                "charge",
                "1209600",
                "1000",
            ],
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return []
    parts = raw.split()
    if len(parts) < 3 or parts[0] != "a(udu)":
        return []
    vals = parts[2:]
    recs: list[tuple[int, float, int]] = []
    for i in range(0, len(vals) - 2, 3):
        try:
            recs.append((int(float(vals[i])), float(vals[i + 1]), int(float(vals[i + 2]))))
        except ValueError:
            break
    recs.sort()
    return recs


GAP_SEC = 900  # a longer hole in the history means the machine was asleep or off


def _points(recs: list[tuple[int, float, int]]) -> list[tuple[int, float]]:
    """Samples oldest-first, without UPower's 0% sentinels.

    The recorded *state* is ignored: it flickers between charging and
    discharging on MagSafe, so direction is read from the percentage instead.
    """
    return [(t, v) for t, v, _st in recs if v >= 1.0]


def _simplify(pts: list[tuple[int, float]], step: float = 0.5) -> list[tuple[int, float]]:
    out: list[tuple[int, float]] = []
    for t, v in pts:
        if not out or abs(v - out[-1][1]) >= step:
            out.append((t, v))
    if out and out[-1][0] != pts[-1][0]:
        out.append(pts[-1])
    return out


def _last_full(pts: list[tuple[int, float]]) -> int | None:
    ts = None
    for t, v in pts:
        if v >= 99.0:
            ts = t
    return ts


def _asleep(pts: list[tuple[int, float]], since: int) -> int:
    """Seconds since `since` that the machine spent suspended or off.

    UPower only writes history while the machine is running, so every hole
    larger than GAP_SEC in the raw samples is time it was not.
    """
    total = 0
    for (t0, _), (t1, _) in zip(pts, pts[1:]):
        if t1 <= since:
            continue
        gap = t1 - max(t0, since)
        if gap > GAP_SEC:
            total += gap
    return total


def _session(
    pts: list[tuple[int, float]], charging: bool
) -> tuple[int, float, bool, int] | None:
    """The charge/discharge run in progress: (start_ts, start_pct, bounded, asleep).

    A suspend leaves a hole in the history, but it does not end the session: if
    the battery was already moving this way before the hole and is still moving
    this way after it, the machine simply slept on battery and the run spans the
    gap. What a hole cannot show is a *turnaround* inside it -- unplugged during
    sleep, say -- so the walk stops at the near side of a gap whenever the step
    before it went the other way, and `bounded` then marks the reported start as
    a lower bound rather than the real one.
    """
    if len(pts) < 2:
        return None
    simp = _simplify(pts)
    if len(simp) < 2:
        return None
    rising = simp[-1][1] > simp[-2][1]
    if rising is not charging:
        return None  # just turned around; the new run has not moved yet

    i = len(simp) - 1
    while i > 0 and (simp[i][1] > simp[i - 1][1]) is rising:
        if simp[i][0] - simp[i - 1][0] > GAP_SEC:
            # Crossing a hole: only trust it if the battery was already going
            # this way before the machine went to sleep.
            if i < 2 or (simp[i - 1][1] > simp[i - 2][1]) is not rising:
                break
        i -= 1

    start_ts, start_pct = simp[i]
    hidden = i > 0 and simp[i][0] - simp[i - 1][0] > GAP_SEC
    return start_ts, start_pct, hidden or i == 0, _asleep(pts, start_ts)


def _cpu() -> dict[str, object] | None:
    """What the active profile actually did to the CPU.

    ppd only reports the profile's *name*; this is the state a user can feel,
    and on hardware ppd cannot drive it is the only proof the buttons work.
    """
    base = "/sys/devices/system/cpu/cpufreq/policy0"
    gov = _read(os.path.join(base, "scaling_governor"))
    cur = _int(_read(os.path.join(base, "scaling_max_freq")))
    top = _int(_read(os.path.join(base, "cpuinfo_max_freq")))
    if not gov or cur is None:
        return None
    no_turbo = _read("/sys/devices/system/cpu/intel_pstate/no_turbo")
    return {
        "gov": gov,
        "maxGhz": round(cur / 1e6, 1),
        "capped": top is not None and cur < top,
        "turbo": None if no_turbo is None else no_turbo == "0",
    }


def _profiles() -> tuple[str, list[str]]:
    dest = "org.freedesktop.UPower.PowerProfiles"
    obj = "/org/freedesktop/UPower/PowerProfiles"
    iface = "org.freedesktop.UPower.PowerProfiles"
    active = "balanced"
    names: list[str] = []
    try:
        raw = subprocess.check_output(
            ["busctl", "get-property", dest, obj, iface, "ActiveProfile"],
            text=True,
        )
        if '"' in raw:
            active = raw.split('"')[1]
    except (OSError, subprocess.CalledProcessError):
        pass
    try:
        raw = subprocess.check_output(
            ["busctl", "get-property", dest, obj, iface, "Profiles"],
            text=True,
        )
        # "Profile" s "power-saver" ...
        import re

        names = re.findall(r'"Profile" s "([^"]+)"', raw)
    except (OSError, subprocess.CalledProcessError):
        pass
    if not names:
        names = ["power-saver", "balanced", "performance"]
    return active, names


def main() -> None:
    sysfs = _bat_path()
    up_path = _upower_path()
    info = _upower_info(up_path) if up_path else {}

    status = (_read(os.path.join(sysfs, "status")) if sysfs else "") or info.get("state", "")
    status = status.lower()
    ac = _read("/sys/class/power_supply/ADP1/online") == "1"

    pct = _int(info.get("percentage"))
    if pct is None and sysfs:
        cap = _read(os.path.join(sysfs, "capacity"))
        pct = _int(cap)

    rate = _float(info.get("energy-rate"))
    energy = _float(info.get("energy"))
    full = _float(info.get("energy-full"))
    design = _float(info.get("energy-full-design"))
    health = _int(info.get("capacity"))
    cycles = _int(info.get("charge-cycles"))
    if cycles is None and sysfs:
        cycles = _int(_read(os.path.join(sysfs, "cycle_count")))
    temp = _float(info.get("temperature"))
    if temp is None and sysfs:
        t = _read(os.path.join(sysfs, "temp"))
        if t:
            temp = _float(t)
            if temp is not None and temp > 200:
                temp = temp / 10.0

    def parse_upower_time(s: str | None) -> str | None:
        if not s:
            return None
        try:
            n, unit = s.split(None, 1)
            n = float(n)
        except ValueError:
            return s
        unit = unit.lower()
        if unit.startswith("hour"):
            return _fmt_eta(n * 3600)
        if unit.startswith("minute"):
            return _fmt_eta(n * 60)
        if unit.startswith("second"):
            return _fmt_eta(n)
        return s

    charging = status in ("charging", "pending-charge") or (ac and status not in ("full", "fully-charged", "discharging"))
    full_state = status in ("full", "fully-charged")
    discharging = (not ac) or status == "discharging"

    pts = _points(_history(up_path)) if up_path else []
    last_full = _last_full(pts)
    sess = _session(pts, charging) if charging != discharging else None

    now = time.time()
    charge_for = unplugged_for = None
    added = used = None
    awake = asleep = None
    bounded = False
    if sess:
        start_ts, start_pct, bounded, asleep_s = sess
        elapsed = now - start_ts
        span = _fmt_dur(elapsed)
        delta = round(abs(pct - start_pct)) if pct is not None else None
        if charging:
            charge_for, added = span, delta
        else:
            unplugged_for, used = span, delta
        if asleep_s > GAP_SEC:
            asleep = _fmt_dur(asleep_s)
            awake = _fmt_dur(max(0, elapsed - asleep_s))

    if full_state:
        mode = "full"
    elif charging:
        mode = "charging"
    else:
        mode = "discharging"

    active, names = _profiles()

    vendor = info.get("vendor") or ""
    model = info.get("model") or ""

    out = {
        "pct": pct,
        "mode": mode,
        "ac": ac,
        "rateW": round(rate, 1) if rate is not None else None,
        "energyWh": round(energy, 1) if energy is not None else None,
        "fullWh": round(full) if full is not None else None,
        "designWh": round(design) if design is not None else None,
        "health": health,
        "cycles": cycles,
        "tempC": round(temp) if temp is not None else None,
        "timeToFull": parse_upower_time(info.get("time to full")) if charging and not full_state else None,
        "timeToEmpty": parse_upower_time(info.get("time to empty")) if discharging and not full_state else None,
        "vendor": vendor,
        "model": model,
        "profile": active,
        "profiles": names,
        "cpu": _cpu(),
        "chargeFor": charge_for,
        "unpluggedFor": unplugged_for,
        "lastFull": _fmt_dur(now - last_full) if last_full else None,
        "addedPct": added,
        "usedPct": used,
        "sessionBounded": bounded,
        "sessionAwake": awake,
        "sessionAsleep": asleep,
    }
    print(json.dumps(out, separators=(",", ":")))


if __name__ == "__main__":
    main()
