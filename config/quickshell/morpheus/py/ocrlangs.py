# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# THE LANGUAGES TESSERACT READS IN — every one installed (tesseract-data-*),
# English first, as tesseract's `-l` wants them: "eng+deu". English is the
# package's own (always there); the setup assistant offers the language
# picked for the system (oracle/setup/LanguageStep). Without this every
# reader asked for English alone, and a German picture came out garbled.
# osd (script detection) and equ (equations) are not languages to read in.
#
# Stdlib only; asked once a process.

import subprocess

_SKIP = {"osd", "equ"}
_cached = None


def langs():
    global _cached
    if _cached is None:
        try:
            r = subprocess.run(["tesseract", "--list-langs"], capture_output=True, timeout=10)
            found = [l.strip() for l in r.stdout.decode("utf-8", "ignore").splitlines()[1:]]
        except (OSError, subprocess.TimeoutExpired):
            found = []
        found = [l for l in found if l and l not in _SKIP]
        found.sort(key=lambda l: (l != "eng", l))
        _cached = "+".join(found) or "eng"
    return _cached
