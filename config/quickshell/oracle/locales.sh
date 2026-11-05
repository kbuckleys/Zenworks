#!/bin/sh
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# THE LANGUAGES glibc can give this computer, for the setup assistant's
# Language step (oracle/setup/LanguageStep.qml). Read only: setting one is
# the assistant's job, through Ceres' password card.
#
#   now <LANG>                         the system's, from localectl
#   tess <package>                     a tesseract-data-* in the repos
#   have <package>                     one installed already
#   <locale>\t<language>\t<territory>\t<made>\t<term>   one per UTF-8 locale
#
# The names are the locale files' own English ones (LC_IDENTIFICATION), so
# "german" finds de_DE; <made> is 1 when locale-gen has built it already;
# <term> is its ISO 639-2 code (LC_ADDRESS lang_term, "deu"), which is
# what tesseract names its languages by — the assistant offers the one
# for the language picked, so text in pictures reads in it too.

now=$(localectl status 2>/dev/null | sed -n 's/.*LANG=\([^ ]*\).*/\1/p' | head -n 1)
printf 'now %s\n' "${now:-${LANG:-}}"
pacman -Ssq '^tesseract-data-' 2>/dev/null | sed 's/^/tess /'
pacman -Qq 2>/dev/null | grep '^tesseract-data-' | sed 's/^/have /'

made=$(locale -a 2>/dev/null | tr 'A-Z' 'a-z' | sed 's/utf-8/utf8/')

grep -E '^[^#].* UTF-8$' /usr/share/i18n/SUPPORTED 2>/dev/null | cut -d' ' -f1 | while read -r loc; do
  # ca_ES.UTF-8@valencia → ca_ES@valencia, the file's name
  base=$(printf '%s' "$loc" | sed 's/\.UTF-8//')
  f=/usr/share/i18n/locales/$base
  [ -r "$f" ] || continue
  names=$(awk -F'"' '/^language[ \t]/ { l = $2 } /^territory[ \t]/ { t = $2 } END { printf "%s\t%s", l, t }' "$f")
  term=$(awk -F'"' '/^lang_term[ \t]/ { print $2; exit }' "$f")
  case $names in "	"*) continue ;; esac
  # locale -a writes utf8, and "aa_ER" (UTF-8 by default) as aa_ER.utf8
  key=$(printf '%s' "$loc" | tr 'A-Z' 'a-z' | sed 's/utf-8/utf8/')
  if printf '%s\n' "$made" | grep -qxF -e "$key" -e "$key.utf8"; then m=1; else m=0; fi
  printf '%s\t%s\t%s\t%s\n' "$loc" "$names" "$m" "$term"
done
