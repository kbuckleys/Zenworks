#!/bin/sh
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# A HYPRCURSOR VERSION OF AN XCURSOR THEME — oracle's Cursor › Make
# (2026-11-04).
#
#   hyprcursor.sh XTHEME NAME DEST
#
# XTHEME is the X theme's directory (it has cursors/), NAME what the new
# one is called (Ora.cursorMadeName: <name>-Hyprcursor, so the Theme row
# pairs it as that theme's twin), DEST where it goes (~/.local/share/icons).
# hyprcursor-util pulls the X cursors apart into PNGs (with xcur2png) and
# packs them as a hyprcursor theme; its manifest is named NAME, which is
# also the directory's name, as Hyprland looks it up by.
#
# A theme of that name already there is replaced only when this made it
# (.zenworks-made); one of yours is left alone (exit 4). Exit 3: a tool is
# missing. Every hyprcursor-util step reads /dev/null for stdin, so its
# "are you sure?" can never hang (it answers no, and this fails).

src="$1"
name="$2"
dest="$3"
[ -d "$src/cursors" ] || { echo "not an XCursor theme: $src" >&2; exit 2; }
case "$name" in ''|*/*|.*) echo "bad name: $name" >&2; exit 2 ;; esac
[ -n "$dest" ] || exit 2
command -v hyprcursor-util >/dev/null 2>&1 || { echo "hyprcursor-util is missing" >&2; exit 3; }
command -v xcur2png >/dev/null 2>&1 || { echo "xcur2png is missing" >&2; exit 3; }

final="$dest/$name"
if [ -e "$final" ] && [ ! -f "$final/.zenworks-made" ]; then
	echo "$final is not one oracle made" >&2
	exit 4
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/zen-hyprcursor.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT INT TERM

src=$(cd "$src" && pwd -P) || exit 1
hyprcursor-util --extract "$src" -o "$tmp" </dev/null >"$tmp/log" 2>&1
ex="$tmp/extracted_${src##*/}"
if [ ! -f "$ex/manifest.hl" ]; then cat "$tmp/log" >&2; exit 1; fi

# the manifest hyprcursor-util writes says "Extracted Theme"
{
	printf 'name = %s\n' "$name"
	printf 'description = %s, made a Hyprcursor theme by Zenworks (oracle/hyprcursor.sh)\n' "${src##*/}"
	printf 'version = 0.1\n'
	printf 'cursors_directory = hyprcursors\n'
} >"$ex/manifest.hl"

mkdir "$tmp/made" || exit 1
hyprcursor-util --create "$ex" -o "$tmp/made" </dev/null >"$tmp/log" 2>&1
made="$tmp/made/theme_$name"
if [ ! -f "$made/manifest.hl" ]; then cat "$tmp/log" >&2; exit 1; fi
touch "$made/.zenworks-made"

mkdir -p "$dest" || exit 1
# beside the old one first, then in its place: never half a theme
rm -rf "$dest/.$name.new"
mv "$made" "$dest/.$name.new" || exit 1
rm -rf "$final"
mv "$dest/.$name.new" "$final" || exit 1
exit 0
