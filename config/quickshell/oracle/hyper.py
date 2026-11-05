#!/usr/bin/env python3
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# hyper.py — THE HYPER KEY (2026-11-03, Oracle's Shortcuts). One key made
# Ctrl+Alt+Shift+Super at once, Raycast's Hyper: a fourth hand of chords no
# app has taken. Done the compositor's own way, no daemon and no root: your
# layout compiled to a keymap (xkbcli, with your layout, variant, options,
# model and rules), that one key's line written over, and Hyprland pointed
# at the file (input.lua's kb_file). Every chord with all four held reads
# as Hyper in Shortcuts.
#
#   hyper.py <out> <key> <layout> <variant> <options> <model> <rules>
#
# key: caps | rctrl | menu. Prints the file written; exits 1 with a reason
# on stderr when the layout does not compile. Caps Lock itself, when it is
# the one taken, can be had from both Shift keys (Oracle adds
# shift:both_capslock to the options it passes).

import os
import re
import subprocess
import sys

KEYS = {"caps": "CAPS", "rctrl": "RCTL", "menu": "COMP"}
ALL_FOUR = "Shift+Control+Mod1+Mod4"


def compile_keymap(layout, variant, options, model, rules):
    argv = ["xkbcli", "compile-keymap"]
    for flag, v in (("--layout", layout), ("--variant", variant), ("--options", options),
                    ("--model", model), ("--rules", rules)):
        if v:
            argv += [flag, v]
    r = subprocess.run(argv, capture_output=True, text=True, timeout=20)
    if r.returncode != 0 or "xkb_symbols" not in r.stdout:
        # stderr of only blank lines had no last line: an IndexError, uncaught
        lines = (r.stderr or "").strip().splitlines()
        raise ValueError(lines[-1] if lines else "the layout did not compile")
    return r.stdout


# the keymap with `name`'s key made Hyper: its own line replaced, and it
# taken out of whatever modifier it was (Caps out of Lock, Right Ctrl out of
# Control), so only the four it sets are held
def patch(keymap, name):
    line = "\tkey <%s> { type= \"ONE_LEVEL\", symbols[1]= [ Hyper_L ], actions[1]= [ SetMods(modifiers=%s) ] };" % (name, ALL_FOUR)
    start = keymap.index("xkb_symbols")
    head, body = keymap[:start], keymap[start:]
    pat = re.compile(r"^[ \t]*key <%s>[^;]*?\};[ \t]*$" % re.escape(name), re.M | re.S)
    if pat.search(body):
        body = pat.sub(lambda m: line, body, count=1)
    else:
        body = body.replace("{", "{\n" + line, 1)

    def unmap(m):
        keys = [k.strip() for k in m.group(2).split(",") if k.strip() and k.strip() != "<%s>" % name]
        return "" if not keys else "%s{ %s };" % (m.group(1), ", ".join(keys))

    body = re.sub(r"(modifier_map\s+\w+\s*)\{([^}]*)\};", unmap, body)
    return head + body


def main():
    if len(sys.argv) < 8:
        print("hyper.py <out> <caps|rctrl|menu> <layout> <variant> <options> <model> <rules>", file=sys.stderr)
        sys.exit(2)
    out, key = sys.argv[1], sys.argv[2]
    if key not in KEYS:
        print("no such key: " + key, file=sys.stderr)
        sys.exit(2)
    try:
        text = patch(compile_keymap(*sys.argv[3:8]), KEYS[key])
    except (ValueError, OSError, subprocess.TimeoutExpired) as e:
        print(str(e) or "the layout did not compile", file=sys.stderr)
        sys.exit(1)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out + ".part", "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(out + ".part", out)
    print(out)


if __name__ == "__main__":
    main()
