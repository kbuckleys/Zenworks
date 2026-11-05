// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

.pragma library
// ONE COPY FOR THE WHOLE SHELL. Without the pragma every component instance
// that imports this file evaluated all of it again (see morpheus/icons.js).

// Parse /usr/share/unicode/emoji/emoji-test.txt (Unicode 17.0).
// Keeps fully-qualified + minimally-qualified entries with their names;
// components (skin tones, ZWJ pieces) and unqualified duplicates are dropped.
// A skin-toned one is not an entry of its own (2026-11-04): it is kept on
// its base as `tones` ({ light: "👋🏻", … }), for Oracle's Skin tone, and
// one of two different tones (two people) is dropped.
const TONE_RE = /[:,]\s*((?:light|medium-light|medium|medium-dark|dark) skin tone)(?:, ((?:light|medium-light|medium|medium-dark|dark) skin tone))?$/;
function foldTones(entries) {
  const byName = {};
  for (const e of entries) if (!TONE_RE.test(e.name)) byName[e.name] = e;
  const out = [];
  for (const e of entries) {
    const m = TONE_RE.exec(e.name);
    if (!m) { out.push(e); continue; }
    if (m[2] && m[2] !== m[1]) continue;
    const base = byName[e.name.slice(0, m.index)];
    if (!base) continue;
    if (!base.tones) base.tones = {};
    base.tones[m[1].replace(/ skin tone$/, "")] = e.char;
  }
  return out;
}
// the emoji in `tone` ("" or "none" for its own yellow) where it has one
function toned(e, tone) { return e && e.tones && tone && e.tones[tone] || (e ? e.char : ""); }
function parseEmojiTest(text) {
  const entries = [];
  let group = "", subgroup = "";
  for (const line of String(text).split("\n")) {
    if (line.startsWith("# group: ")) { group = line.slice(9).trim(); continue; }
    if (line.startsWith("# subgroup: ")) { subgroup = line.slice(12).trim(); continue; }
    if (!line || line.startsWith("#")) continue;

    const m = line.match(/^([0-9A-F][0-9A-F ]*?)\s*;\s*(\S+)\s*#\s*(.+)$/);
    if (!m) continue;
    const status = m[2];
    if (status === "component" || status === "unqualified") continue;

    // tail is "<emoji> E<version> <name>" — lazy up to the version token,
    // which the emoji itself can never contain
    const tail = m[3].match(/^(.*?)\s+E[0-9]+(?:\.[0-9]+)?\s+(.*)$/);
    if (!tail) continue;

    let char = "";
    for (const cp of m[1].trim().split(" ")) {
      const n = parseInt(cp, 16);
      if (n > 0) char += String.fromCodePoint(n);
    }

    entries.push({
      char: char,
      name: tail[2],
      group: group,
      subgroup: subgroup,
    });
  }
  return foldTones(entries);
}

// .nf-<class>:before { content: "\XXXX" } from nerdfonts.com webfont.css
function parseNerdCss(css) {
  const icons = [];
  const re = /\.((?:nf-)?[a-z0-9_-]+):before\s*\{\s*content:\s*"\\([0-9a-f]+)"/gi;
  let m;
  while ((m = re.exec(css)) !== null) {
    icons.push({
      cls: m[1],
      code: m[2],
      char: String.fromCodePoint(parseInt(m[2], 16)),
    });
  }
  return icons;
}

// What an entry is found by, lowercased once and kept on it (`_k`): five
// thousand names lowercased again on every key was most of a keystroke in
// Cynosure (2026-11-02). The match is the same: the class or the codepoint
// for a nerd glyph, the name or the character for an emoji.
function keyOf(e) {
  if (e._k === undefined)
    e._k = e.cls ? e.cls.toLowerCase() + "\u0000" + String(e.code).toLowerCase()
      : (e.name ? e.name.toLowerCase() : "") + "\u0000" + e.char;
  return e._k;
}
function filterEntries(entries, query) {
  const q = String(query).toLowerCase();
  if (!q) return entries;
  return entries.filter((e) => keyOf(e).indexOf(q) >= 0);
}
