#!/usr/bin/env python3
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# browsers.py — THE BROWSERS' BOOKMARKS AND HISTORY, for Cynosure's "bm …"
# and "browsed …" (2026-11-03). Every Chromium kind (Brave, Chromium,
# Chrome, Vivaldi, Edge) and every Firefox kind (Firefox, LibreWolf, Zen)
# found under the home, each profile.
#
#   browsers.py bookmarks         [ { title, url, browser, folder } ]
#   browsers.py history <words>   [ { title, url, browser, when, visits } ]
#
# `when` is ms since the epoch. History is opened read-only and immutable,
# so a running browser's lock is no matter (what it has not written out yet
# is simply not seen). Nothing is written anywhere.

import glob
import json
import os
import sqlite3
import sys

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")

# each a glob under the config directory: every channel of a browser
# (Brave-Browser, -Beta, -Nightly, Brave-Origin; Chrome's beta and unstable)
CHROMIUMS = [
    ("Brave", "BraveSoftware/*"),
    ("Chromium", "chromium"),
    ("Chrome", "google-chrome*"),
    ("Vivaldi", "vivaldi*"),
    ("Edge", "microsoft-edge*"),
]
# the same browsers as Flatpaks keep their config under their own app id
FLATPAK = os.path.join(HOME, ".var", "app", "*", "config")
FIREFOXES = [
    ("Firefox", ".mozilla/firefox"),
    ("LibreWolf", ".librewolf"),
    ("Zen", ".zen"),
]
# Chromium counts microseconds from 1601
WEBKIT_EPOCH_US = 11644473600 * 1000000
HISTORY_MAX = 80


def chromium_profiles():
    for name, d in CHROMIUMS:
        for root in (CONFIG, FLATPAK):
            for base in sorted(glob.glob(os.path.join(root, d))):
                for p in sorted(glob.glob(base + "/Default") + glob.glob(base + "/Profile *")):
                    yield name, p


def firefox_profiles():
    for name, d in FIREFOXES:
        for p in sorted(glob.glob(os.path.join(HOME, d, "*")) + glob.glob(os.path.join(HOME, ".var", "app", "*", d, "*"))):
            if os.path.isfile(os.path.join(p, "places.sqlite")):
                yield name, p


def readonly(path):
    return sqlite3.connect("file:" + path + "?immutable=1", uri=True)


def bookmarks():
    out = []
    for browser, p in chromium_profiles():
        try:
            with open(os.path.join(p, "Bookmarks"), encoding="utf-8") as f:
                roots = json.load(f).get("roots", {})
        except (OSError, ValueError):
            continue

        def walk(node, folder):
            if node.get("type") == "url":
                out.append({"title": node.get("name", ""), "url": node.get("url", ""),
                            "browser": browser, "folder": folder})
            for c in node.get("children", []) or []:
                walk(c, node.get("name", "") if node.get("type") == "folder" else folder)

        for r in roots.values():
            if isinstance(r, dict):
                walk(r, "")
    for browser, p in firefox_profiles():
        try:
            db = readonly(os.path.join(p, "places.sqlite"))
            rows = db.execute(
                "SELECT b.title, p.url, f.title FROM moz_bookmarks b JOIN moz_places p ON p.id = b.fk "
                "LEFT JOIN moz_bookmarks f ON f.id = b.parent WHERE b.type = 1 AND p.url LIKE 'http%'").fetchall()
            db.close()
        except sqlite3.Error:
            continue
        for title, url, folder in rows:
            out.append({"title": title or "", "url": url, "browser": browser, "folder": folder or ""})
    return out


def history(words):
    like = "%" + words.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
    best = {}

    def keep(row):
        had = best.get(row["url"])
        if not had or had["when"] < row["when"]:
            best[row["url"]] = row

    for browser, p in chromium_profiles():
        path = os.path.join(p, "History")
        if not os.path.isfile(path):
            continue
        try:
            db = readonly(path)
            rows = db.execute(
                "SELECT url, title, last_visit_time, visit_count FROM urls WHERE hidden = 0 "
                "AND (url LIKE ? ESCAPE '\\' OR title LIKE ? ESCAPE '\\') "
                "ORDER BY last_visit_time DESC LIMIT ?", (like, like, HISTORY_MAX)).fetchall()
            db.close()
        except sqlite3.Error:
            continue
        for url, title, t, n in rows:
            keep({"title": title or "", "url": url, "browser": browser,
                  "when": max(0, (t - WEBKIT_EPOCH_US) // 1000), "visits": n})
    for browser, p in firefox_profiles():
        try:
            db = readonly(os.path.join(p, "places.sqlite"))
            rows = db.execute(
                "SELECT url, title, last_visit_date, visit_count FROM moz_places "
                "WHERE last_visit_date IS NOT NULL AND hidden = 0 "
                "AND (url LIKE ? ESCAPE '\\' OR title LIKE ? ESCAPE '\\') "
                "ORDER BY last_visit_date DESC LIMIT ?", (like, like, HISTORY_MAX)).fetchall()
            db.close()
        except sqlite3.Error:
            continue
        for url, title, t, n in rows:
            keep({"title": title or "", "url": url, "browser": browser, "when": (t or 0) // 1000, "visits": n})
    return sorted(best.values(), key=lambda r: -r["when"])[:HISTORY_MAX]


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what == "bookmarks":
        print(json.dumps(bookmarks()))
    elif what == "history":
        print(json.dumps(history(" ".join(sys.argv[2:]).strip())))
    else:
        print("browsers.py bookmarks | history <words>", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
