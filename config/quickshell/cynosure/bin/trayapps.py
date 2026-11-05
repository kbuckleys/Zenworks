# trayapps.py — WHAT RUNS IN THE TRAY (2026-11-04, Cynosure's "quit").
# Every tray icon's process, read from the bus: each registered item's
# connection asked for its pid (org.freedesktop.DBus GetConnectionUnixProcessID),
# so Steam is "steam" and Claude's icon is claude-desktop, whatever the icon
# calls itself. Prints JSON: [{ pid, comm, classes }], `classes` the
# classes of Hyprland's windows of that process (none: in the tray alone).

import json
import subprocess

WATCHER = ["org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
           "RegisteredStatusNotifierItems"]


def run(argv):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def items():
    out = run(["busctl", "--user", "--json=short", "get-property"] + WATCHER)
    try:
        return [str(s).split("/", 1)[0] for s in json.loads(out).get("data", [])]
    except (ValueError, AttributeError):
        return []


def pid_of(service):
    out = run(["busctl", "--user", "--json=short", "call", "org.freedesktop.DBus", "/", "org.freedesktop.DBus",
               "GetConnectionUnixProcessID", "s", service])
    try:
        return int(json.loads(out)["data"][0])
    except (ValueError, KeyError, IndexError, TypeError):
        return 0


def window_classes():
    by = {}
    try:
        for c in json.loads(run(["hyprctl", "clients", "-j"]) or "[]"):
            by.setdefault(int(c.get("pid", 0)), set()).add(str(c.get("class", "")))
    except (ValueError, AttributeError, TypeError):
        pass
    return by


def main():
    wins = window_classes()
    seen = set()
    out = []
    for service in items():
        pid = pid_of(service)
        if pid <= 1 or pid in seen:
            continue
        seen.add(pid)
        try:
            with open("/proc/%d/comm" % pid, encoding="utf-8") as f:
                comm = f.read().strip()
        except OSError:
            continue
        out.append({"pid": pid, "comm": comm, "classes": sorted(wins.get(pid, ()))})
    print(json.dumps(out))


if __name__ == "__main__":
    main()
