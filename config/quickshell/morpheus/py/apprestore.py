#!/usr/bin/env python3
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# APP RESTORE (2026-11-04) — the apps open when a session ends, opened again
# at the next login where they were: their workspace, and a floating one at
# its size and place. Off by default (Oracle's "Reopen apps at login",
# morpheus/AppRestore.qml). Stdlib only.
#
#   apprestore.py save    what is open now, into the snapshot — unless the
#                         session is already ending (hyprshutdown running:
#                         it closes the apps one by one, and a snapshot
#                         taken then would be of an emptying desktop)
#   apprestore.py plan    the last session's snapshot as launches, once per
#                         Hyprland session, as JSON on stdout:
#                         {"launch": [{"cmd", "rules", "name"}],
#                          "zen": [{"ipc", "title", "workspace", "floating",
#                                   "size", "at"}], "skipped": n}
#                         The shell sends each launch through hypr.js
#                         (execWith), and each Zenworks window's ipc call,
#                         placing that window when it maps (placeWindow).
#
# A window is opened again by its app's .desktop file — StartupWMClass, the
# file's own name, or its Exec's program, matched to the window's class —
# or, with none, by the program its process ran when that is on the PATH
# (no arguments: a file it had open is not guessed at). One launch a window,
# except a web browser's: it reopens its own windows, so it is launched
# once, and a Chromium one with --restore-last-session for its tabs (user,
# 2026-11-04: the pages were gone). Firefox and its kin have no such flag:
# their own "Open previous windows and tabs" does it.
#
# Zenworks' own windows are the shell's (one process, class org.quickshell),
# so no launch rule reaches them: each is opened by its app's ipc call (ZEN,
# by window title) and placed by the shell when it maps. A picker, a capture
# note, a viewer with no file to show and what cannot be launched are
# skipped, and each is noted in apprestore.log beside the snapshot.
#
# Where: $XDG_STATE_HOME/zenworks/apprestore.json (the snapshot, with the
# Hyprland instance that took it), apprestore.log (the last 200 lines).
# A snapshot is never planned in the session that took it, so a shell
# restart does not open everything twice.

import json
import os
import shlex
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import zenpaths  # noqa: E402

QUICKSHELL = "org.quickshell"

# a Zenworks window's title -> the ipc call that opens it again (each app's
# bin/ launcher with no arguments says the same)
ZEN = {
    "oracle": ["Oracle", "open"],
    "ceres": ["Ceres", "window", "store"],
    "chronos": ["Calendar", "open", ""],
    "delphi": ["Delphi", "open", ""],
    "alexandria": ["Alexandria", "open", ""],
    "hestia": ["Hestia", "open", ""],
    "stylus": ["Stylus", "open", ""],
    "kairos": ["Kairos", "open", ""],
    "minerva": ["Minerva", "open", ""],
    "hermes": ["Hermes", "window", ""],
    "clio": ["Clio", "open"],
    "calypso": ["Calypso", "open"],
    "plato": ["Plato", "open", ""],
    "terminus": ["Terminus", "open", ""],
    "hygieia": ["Hygieia", "open"],
}
# a second Terminus window is a new one, not the first shown again
ZEN_MORE = {"terminus": lambda: ["Terminus", "spawn", os.path.expanduser("~")]}

# open for a moment's job, not to be opened again
# (argus: one recording's edit, which a login does not bring back)
PASSING = {"terminus-picker", "plato-capture", "cynosure-camera", "picasso-view", "argus"}

# the Chromium family, by the program its .desktop file runs
CHROMIUM = ("chrom", "brave", "vivaldi", "edge", "opera", "thorium", "helium", "cromite")


def state():
    return zenpaths.state_dir("zenworks")


def snap_path():
    return os.path.join(state(), "apprestore.json")


def log(lines):
    p = os.path.join(state(), "apprestore.log")
    try:
        with open(p) as f:
            old = f.read().splitlines()
    except OSError:
        old = []
    stamp = time.strftime("%Y-%m-%d %H:%M")
    old += [stamp + "  " + l for l in lines]
    zenpaths.write_atomic(p, ("\n".join(old[-200:]) + "\n").encode())


def hyprctl(what):
    r = subprocess.run(["hyprctl", "-j", what], capture_output=True, timeout=5)
    return json.loads(r.stdout.decode("utf-8", "replace") or "[]")


# ── the .desktop files, by what a window's class may be ─────────────────
def app_dirs():
    home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    dirs = [home] + (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    dirs += [os.path.join(home, "flatpak/exports/share"), "/var/lib/flatpak/exports/share"]
    out, seen = [], set()
    for d in dirs:
        a = os.path.join(d, "applications")
        if d and a not in seen and os.path.isdir(a):
            seen.add(a)
            out.append(a)
    return out


def read_desktop(path):
    entry, inside = {}, False
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    inside = line == "[Desktop Entry]"
                    continue
                if inside and "=" in line:
                    k, v = line.split("=", 1)
                    entry.setdefault(k.strip(), v.strip())
    except OSError:
        return None
    if entry.get("Type", "Application") != "Application" or entry.get("Hidden") == "true" or not entry.get("Exec"):
        return None
    # an Exec shlex cannot read (an unclosed quote) is that one file's
    # problem: left out here, it no longer raised through the whole index
    # and cost every window its reopening (audit 2026-11-04)
    try:
        shlex.split(entry["Exec"], posix=True)
    except ValueError:
        return None
    return entry


def exec_line(entry):
    # the field codes out (%f %U …), %% kept as one %
    parts = []
    for w in shlex.split(entry["Exec"], posix=True):
        if len(w) == 2 and w[0] == "%" and w[1] != "%":
            continue
        parts.append(w.replace("%%", "%"))
    return shlex.join(parts) if parts else ""


def desktop_index():
    by = {}
    for d in app_dirs():
        for root, _, files in os.walk(d):
            for n in sorted(files):
                if not n.endswith(".desktop"):
                    continue
                e = read_desktop(os.path.join(root, n))
                if not e:
                    continue
                did = n[:-8].lower()
                prog = os.path.basename((shlex.split(e["Exec"]) or [""])[0]).lower()
                # the first directory wins, as XDG says: yours over the system's
                for key in (("wm", e.get("StartupWMClass", "").lower()), ("id", did),
                            ("tail", did.rsplit(".", 1)[-1]), ("prog", prog)):
                    if key[1]:
                        by.setdefault(key, e)
    return by


def find_app(index, cls):
    c = (cls or "").lower()
    if not c:
        return None
    for kind in ("wm", "id", "tail", "prog"):
        e = index.get((kind, c))
        if e:
            return e
    return None


def from_process(pid):
    # no .desktop file: the program its process ran, when the PATH has it
    try:
        exe = os.path.basename(os.readlink("/proc/%d/exe" % int(pid)))
    except (OSError, ValueError, TypeError):
        return ""
    return exe if exe and shutil.which(exe) else ""


# ── save ─────────────────────────────────────────────────────────────────
def ending():
    r = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "hyprshutdown"], capture_output=True)
    return r.returncode == 0


def save(clients=None, monitors=None):
    if clients is None:
        if ending():
            return 0
        clients, monitors = hyprctl("clients"), hyprctl("monitors")
    mons = {m.get("id"): m for m in monitors or []}
    wins = []
    for c in clients:
        if not c.get("mapped", True) or c.get("hidden"):
            continue
        ws = (c.get("workspace") or {}).get("name", "")
        m = mons.get(c.get("monitor")) or {}
        at, size = c.get("at") or [0, 0], c.get("size") or [0, 0]
        wins.append({
            "class": c.get("class", ""), "initialClass": c.get("initialClass", ""),
            "title": c.get("title", ""), "workspace": ws, "floating": bool(c.get("floating")),
            "monitor": m.get("name", ""),
            # the place on its own monitor: what the move rule reads
            "at": [at[0] - m.get("x", 0), at[1] - m.get("y", 0)], "size": size,
            # and on the whole layout: what a Zenworks window is moved to
            "abs": list(at),
            "pid": c.get("pid", 0), "focusHistoryID": c.get("focusHistoryID", 0),
        })
    # the least recently used first, so the one you were in opens last
    wins.sort(key=lambda w: -w["focusHistoryID"])
    snap = {"instance": os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""), "saved": int(time.time()), "windows": wins}
    # the program for each, found now, while its process is still there
    for w in snap["windows"]:
        w["exe"] = from_process(w.pop("pid"))
        w.pop("focusHistoryID")
    zenpaths.write_atomic(snap_path(), (json.dumps(snap, indent=1) + "\n").encode())
    return 0


# ── plan ─────────────────────────────────────────────────────────────────
def workspace_selector(name):
    if not name:
        return ""
    if name.isdigit() or name.startswith("special:"):
        return name
    return "name:" + name


def workspace_rule(name):
    sel = workspace_selector(name)
    return sel + " silent" if sel else ""


def plan(snap=None, index=None, instance=None):
    if snap is None:
        try:
            with open(snap_path()) as f:
                snap = json.load(f)
        except (OSError, ValueError):
            return {"launch": [], "skipped": 0}
    instance = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "") if instance is None else instance
    # this session's own snapshot (a shell restart), or one planned already
    if not instance or snap.get("instance") == instance or snap.get("planned") == instance:
        return {"launch": [], "skipped": 0}
    index = desktop_index() if index is None else index
    launch, zen, notes, quiet, browsers, zseen = [], [], [], [], set(), set()
    for w in snap.get("windows", []):
        cls = w.get("initialClass") or w.get("class")
        label = w.get("title") or cls or "a window"
        if cls == QUICKSHELL or w.get("class") == QUICKSHELL:
            title = w.get("title", "")
            ipc = ZEN.get(title)
            if ipc and title in zseen:
                ipc = ZEN_MORE[title]() if title in ZEN_MORE else None
                if not ipc:
                    continue
            if not ipc:
                # a picker or a capture note was for that moment: not counted
                # as a miss, so it brings no notification at login
                (quiet if title in PASSING else notes).append(
                    "skipped %s: a Zenworks window that is not reopened" % (title or "untitled"))
                continue
            zseen.add(title)
            # a named workspace as Hyprland reads one ("web" bare is no name)
            zen.append({"ipc": ipc, "title": title, "workspace": workspace_selector(w.get("workspace", "")),
                        "floating": bool(w.get("floating")), "size": w.get("size") or [0, 0],
                        "at": w.get("abs") or w.get("at") or [0, 0]})
            continue
        e = find_app(index, w.get("class")) or find_app(index, w.get("initialClass"))
        cmd = exec_line(e) if e else (w.get("exe") or "")
        if not cmd:
            notes.append("skipped %s (%s): no app to open it with" % (label, cls or "no class"))
            continue
        name = (e or {}).get("Name") or cls
        if e and "WebBrowser" in (e.get("Categories") or "").split(";"):
            if name in browsers:
                continue
            browsers.add(name)
            prog = os.path.basename((shlex.split(cmd) or [""])[0]).lower()
            if any(k in prog for k in CHROMIUM) and "--restore-last-session" not in cmd:
                cmd += " --restore-last-session"
        rules = {}
        ws = workspace_rule(w.get("workspace", ""))
        if ws:
            rules["workspace"] = ws
        if w.get("floating"):
            rules["float"] = True
            sz, at = w.get("size") or [0, 0], w.get("at") or [0, 0]
            if sz[0] > 0 and sz[1] > 0:
                rules["size"] = "%d %d" % (sz[0], sz[1])
                rules["move"] = "%d %d" % (at[0], at[1])
            if w.get("monitor"):
                rules["monitor"] = w["monitor"]
        launch.append({"cmd": cmd, "rules": rules, "name": name})
    # planned: marked in the snapshot itself, for this session
    snap["planned"] = instance
    try:
        zenpaths.write_atomic(snap_path(), (json.dumps(snap, indent=1) + "\n").encode())
    except OSError:
        pass
    log(["reopened %s" % l["name"] for l in launch] + ["reopened %s" % z["title"] for z in zen] + notes + quiet)
    return {"launch": launch, "zen": zen, "skipped": len(notes)}


def main(argv):
    if len(argv) < 2 or argv[1] not in ("save", "plan"):
        print("usage: apprestore.py save|plan", file=sys.stderr)
        return 2
    try:
        if argv[1] == "save":
            return save()
        print(json.dumps(plan()))
        return 0
    except (OSError, subprocess.TimeoutExpired, ValueError) as e:
        print("apprestore: %s" % e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
