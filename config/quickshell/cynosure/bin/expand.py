#!/usr/bin/env python3
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# expand.py — SNIPPET KEYWORDS, TYPED ANYWHERE (2026-11-03, Raycast's
# snippet expansion). Reads the keyboards (evdev: you are in the input
# group) and turns their keys into characters through your own layout
# (libxkbcommon, with Hyprland's kb_layout / kb_variant / kb_options), keeps
# the last few typed, and when they end in one of the keywords given, prints
# that keyword on a line of its own. Cynosure does the rest: the keyword
# erased, the snippet typed in its place.
#
#   expand.py <keyword> …     one keyword a line on stdout, as each is typed
#
# Nothing typed is written anywhere or printed but a keyword. What is kept
# is at most the longest keyword's length, and it is forgotten on Return,
# Tab, Escape, an arrow, a click of a key with Ctrl, Alt or Super held, and
# on every match. Keyboards plugged in later are picked up within seconds.

import ctypes
import json
import os
import select
import subprocess
import sys
import time

try:
    import evdev
    from evdev import ecodes
except ImportError:
    print("needs python-evdev: pacman -S python-evdev", file=sys.stderr)
    sys.exit(3)

RESCAN_S = 5
# the keys that end what is being typed: the caret has gone somewhere else
FORGET = {ecodes.KEY_ENTER, ecodes.KEY_KPENTER, ecodes.KEY_TAB, ecodes.KEY_ESC, ecodes.KEY_UP, ecodes.KEY_DOWN,
          ecodes.KEY_LEFT, ecodes.KEY_RIGHT, ecodes.KEY_HOME, ecodes.KEY_END, ecodes.KEY_PAGEUP, ecodes.KEY_PAGEDOWN}
HELD = {ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL, ecodes.KEY_LEFTALT, ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA}


# ── the layout ──────────────────────────────────────────────────────────────
class RuleNames(ctypes.Structure):
    _fields_ = [("rules", ctypes.c_char_p), ("model", ctypes.c_char_p), ("layout", ctypes.c_char_p),
                ("variant", ctypes.c_char_p), ("options", ctypes.c_char_p)]


def hypr_option(name):
    try:
        r = subprocess.run(["hyprctl", "getoption", name, "-j"], capture_output=True, text=True, timeout=3)
        v = json.loads(r.stdout).get("str", "")
        return "" if v in ("", "[[EMPTY]]") else v
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return ""


class Layout:
    def __init__(self):
        x = ctypes.CDLL("libxkbcommon.so.0")
        x.xkb_context_new.restype = ctypes.c_void_p
        x.xkb_keymap_new_from_names.restype = ctypes.c_void_p
        x.xkb_keymap_new_from_names.argtypes = [ctypes.c_void_p, ctypes.POINTER(RuleNames), ctypes.c_int]
        x.xkb_state_new.restype = ctypes.c_void_p
        x.xkb_state_new.argtypes = [ctypes.c_void_p]
        x.xkb_state_update_key.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_int]
        x.xkb_state_key_get_utf8.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_char_p, ctypes.c_size_t]
        self.x = x
        ctx = x.xkb_context_new(0)
        enc = lambda s: s.encode() if s else None
        names = RuleNames(None, None, enc(hypr_option("input:kb_layout") or "us"),
                          enc(hypr_option("input:kb_variant")), enc(hypr_option("input:kb_options")))
        keymap = x.xkb_keymap_new_from_names(ctx, ctypes.byref(names), 0)
        if not keymap:
            names = RuleNames(None, None, b"us", None, None)
            keymap = x.xkb_keymap_new_from_names(ctx, ctypes.byref(names), 0)
        self.state = x.xkb_state_new(keymap)
        self.buf = ctypes.create_string_buffer(16)

    # the character a key makes now (xkb codes are evdev's plus 8)
    def char(self, code):
        n = self.x.xkb_state_key_get_utf8(self.state, code + 8, self.buf, 16)
        return self.buf.raw[:n].decode("utf-8", "ignore") if n > 0 else ""

    def key(self, code, down):
        self.x.xkb_state_update_key(self.state, code + 8, 1 if down else 0)


# ── the keyboards ───────────────────────────────────────────────────────────
def keyboards(known):
    found = {}
    for path in evdev.list_devices():
        if path in known:
            found[path] = known[path]
            continue
        try:
            d = evdev.InputDevice(path)
        except OSError:
            continue
        keys = d.capabilities().get(ecodes.EV_KEY, [])
        if ecodes.KEY_A in keys and ecodes.KEY_Z in keys and ecodes.KEY_SPACE in keys:
            found[path] = d
        else:
            d.close()
    for path, d in known.items():
        if path not in found:
            try:
                d.close()
            except OSError:
                pass
    return found


def main():
    words = sorted({w for w in sys.argv[1:] if len(w) >= 2 and not any(c.isspace() for c in w)}, key=len, reverse=True)
    if not words:
        return
    keep = max(len(w) for w in words)
    layout = Layout()
    devs = {}
    scanned = 0.0
    typed = ""
    held = set()
    while True:
        if time.monotonic() - scanned > RESCAN_S:
            devs = keyboards(devs)
            scanned = time.monotonic()
        if not devs:
            time.sleep(RESCAN_S)
            continue
        ready, _, _ = select.select(list(devs.values()), [], [], RESCAN_S)
        for d in ready:
            try:
                events = list(d.read())
            except OSError:
                devs = {p: x for p, x in devs.items() if x is not d}
                continue
            for e in events:
                if e.type != ecodes.EV_KEY:
                    continue
                code, value = e.code, e.value
                if value == 0:
                    layout.key(code, False)
                    held.discard(code)
                    continue
                if value == 1:
                    layout.key(code, True)
                if code in HELD:
                    held.add(code)
                    continue
                if held or code in FORGET:
                    typed = ""
                    continue
                if code == ecodes.KEY_BACKSPACE:
                    typed = typed[:-1]
                    continue
                ch = layout.char(code)
                if not ch or not ch.isprintable():
                    continue
                typed = (typed + ch)[-keep:]
                for w in words:
                    if typed.endswith(w):
                        print(w, flush=True)
                        typed = ""
                        break


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
