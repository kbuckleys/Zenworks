#!/usr/bin/env python3
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# PICASSO'S SCAN, IN ONE PROCESS (user, 2026-10-15: quick access indexing was
# slow). The shell loop it replaces paid two `stat`s, a printf | md5sum | cut
# and a touch per picture — five processes each, every scan — and made any
# missing thumbnail one at a time before a single row came back.
#
#   scan.py list DIR THUMBDIR SIZE EXTS   every picture, its thumbnail if the
#                                         pool already has it
#   scan.py make DIR THUMBDIR SIZE EXTS   the same, after making the missing
#                                         thumbnails, as many at once as there
#                                         are cores
#
# A row: path \t thumb \t mtime \t size (thumb empty when there is none) —
# picasso.js parseRows. The key is morpheus/thumbs.js keyScript's, byte for
# byte: md5 of "path|size|mtime" with the mtime in whole seconds, so terminus
# and picasso keep finding each other's thumbnails.

import hashlib
import os
import subprocess
import threading
import sys
from concurrent.futures import ThreadPoolExecutor


def walk(top, exts):
    out = []
    for root, dirs, files in os.walk(top):
        # dot-directories pruned: a stray .thumbnails or .git is not art
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if f.startswith("."):
                continue
            dot = f.rfind(".")
            if dot < 0 or f[dot + 1:].lower() not in exts:
                continue
            p = os.path.join(root, f)
            try:
                st = os.lstat(p)
            except OSError:
                continue
            if not os.path.isfile(p) or os.path.islink(p):
                continue
            out.append((p, st.st_size, int(st.st_mtime), st.st_mtime))
    out.sort(key=lambda r: os.fsencode(r[0]))
    return out


def thumb_of(thumbdir, p, size, mt):
    key = hashlib.md5(os.fsencode(p) + b"|%d|%d" % (size, mt)).hexdigest()
    return os.path.join(thumbdir, key + ".jpg")


def none_of(path):
    # "this one gets no thumbnail": beside the key, swept by age as the
    # thumbnails are (morpheus/thumbs.js sweep)
    return os.path.splitext(path)[0] + ".none"


def has(path):
    try:
        return os.path.getsize(path) > 0
    except OSError:
        return False


# WHO ASKED. The shell runs this under a tethered sh (Picasso.scanArgv), and
# when the shell goes — a restart, a crash, a test harness quitting — that sh
# dies with it and this process is handed to init. A make of a whole
# directory then went on without anyone to read it, one magick per core
# (2026-11-05: a harness' two scans ran on for minutes). So each picture
# asks first: once the parent has changed, the rest are skipped and only
# the pictures already in hand finish.
PARENT = os.getppid()


def orphaned():
    return os.getppid() != PARENT


JPEG_EXTS = (".jpg", ".jpeg", ".jpe")


def make(src, out, px):
    if orphaned():
        return
    # as morpheus/thumbs.js generate (audit 11-08): a picture that uses
    # transparency gets no JPEG in the shared pool, or Terminus and the
    # shelf would show it flattened where they draw the picture itself
    if not src.lower().endswith(JPEG_EXTS):
        # the first frame: an animated one answers once per frame
        r = subprocess.run(["magick", "identify", "-format", "%[opaque]", src + "[0]"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        if r.stdout.strip() == b"False":
            # remembered, so the decode is paid once per version of a file
            open(none_of(out), "w").close()
            return
    # beside, then moved in: a half-written file under the key is trusted
    # by every reader for good
    root, ext = os.path.splitext(out)
    tmp = "%s.part%d-%d%s" % (root, os.getpid(), threading.get_ident(), ext)
    subprocess.run(["magick", "-define", "jpeg:size=%dx%d" % (2 * px, 2 * px),
                    src + "[0]", "-auto-orient", "-thumbnail", "%dx%d" % (px, px),
                    "-strip", "-quality", "85", tmp],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        if os.path.getsize(tmp) > 0:
            os.replace(tmp, out)
    except OSError:
        pass
    try:
        os.unlink(tmp)
    except OSError:
        pass


def main():
    mode, top, thumbdir, px, exts = sys.argv[1:6]
    px = int(px)
    exts = set(e.lower() for e in exts.split(",") if e)
    os.makedirs(thumbdir, exist_ok=True)
    rows = walk(top, exts)
    thumbs = [thumb_of(thumbdir, p, sz, mt) for p, sz, mt, _ in rows]
    there = [has(t) for t in thumbs]
    if mode == "make":
        missing = []
        for r, t, h in zip(rows, thumbs, there):
            if h:
                continue
            if os.path.exists(none_of(t)):
                try:
                    os.utime(none_of(t))
                except OSError:
                    pass
                continue
            missing.append((r[0], t))
        if missing:
            with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
                list(pool.map(lambda m: make(m[0], m[1], px), missing))
            there = [has(t) for t in thumbs]
    out = []
    for (p, sz, mt, _), t, h in zip(rows, thumbs, there):
        if h:
            # touched: an untouched thumbnail is one the sweep deletes
            # (morpheus/thumbs.js sweep)
            try:
                os.utime(t)
            except OSError:
                pass
        # "-": none on purpose (a .none marker), told apart from missing,
        # or every scan of a directory with one transparent picture ran a
        # second, useless make walk (audit 2026-11-09)
        out.append("%s\t%s\t%d\t%d" % (p, t if h else ("-" if os.path.exists(none_of(t)) else ""), mt, sz))
    sys.stdout.write("\n".join(out) + ("\n" if out else ""))


if __name__ == "__main__":
    main()
