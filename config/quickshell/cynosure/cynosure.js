// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

.pragma library
.import qs.morpheus as Morpheus
.import Quickshell as QuickshellModule
.import "../artemis/artemis.js" as Artemis
.import "../folio/folio.js" as Folio
.import "../ideo/ideo.js" as Ideo
.import "../lexi/lexi.js" as Lexicon
.import "../ceres/store.js" as Store
.import "../clio/notes.js" as Notes
.import "../chronos/chronos.js" as Chr
// ONE COPY FOR THE WHOLE SHELL. Without the pragma every component instance
// that imports this file evaluated all of it again (see morpheus/icons.js).
// The shell's singletons come in through the imports above (the same
// instances); the node tests hand in stubs of their own.
var Desktop = typeof Morpheus !== "undefined" ? Morpheus.Desktop : globalThis.Desktop;
var Paths = typeof Morpheus !== "undefined" ? Morpheus.Paths : globalThis.Paths;
var Strings = typeof Morpheus !== "undefined" ? Morpheus.Strings : globalThis.Strings;
var Quickshell = typeof QuickshellModule !== "undefined" ? QuickshellModule.Quickshell : globalThis.Quickshell;

function histPath() {
  return Paths.cacheDir() + "/cynosure-history";
}

function freqPath() {
  return Paths.cacheDir() + "/cynosure-freq";
}

// ── WHAT YOU SEARCHED (2026-11-01) ─────────────────────────────────────────
// The lines that led somewhere, newest first, for up on an empty line to
// bring back (a shell's history). Kept in the cache with the frecency.
const QUERIES_MAX = 30;
function queriesPath() {
  return Paths.cacheDir() + "/cynosure-searches";
}
function parseQueries(text) {
  return String(text || "").split("\n").filter((l) => l.trim() !== "").slice(0, QUERIES_MAX);
}
function serializeQueries(list) {
  return (list || []).length ? list.join("\n") + "\n" : "";
}
// this line first, once, and the oldest let go past the limit
function addQuery(list, q) {
  const t = String(q || "").trim();
  if (t === "") return (list || []).slice();
  return [t].concat((list || []).filter((x) => x !== t)).slice(0, QUERIES_MAX);
}

// ── THE DICTIONARY AND THE TRANSLATOR, AS CARDS (2026-11-01) ──────────────
// What the line asks of Lexi, or null:
//   { mode: "dict", word, lang }          define serendipity · def faire in french
//                                         · serendipity meaning · meaning of X
//   { mode: "trans", text, to, from }     tr good morning · translate hola to english
//                                         · hello in spanish · how do you say cat in german
// `lang`, `to` and `from` are lexi.js langFor's { code, name, en } or null; the
// bare word ("def", "tr ") asks with nothing, for the card's recents.
// "X in Y" is a translation only when Y is a language by name, so "time in
// tokyo" and "5 usd in eur" stay the calculator's.
const LEXI_WORDS = 6;
function words(s) { return String(s).trim().split(/\s+/).filter((w) => w !== "").length; }
function lexiTarget(rest) {
  const t = String(rest || "").trim();
  let m = /^(.*?)\s+from\s+(\S+(?: \S+)?)\s+(?:to|into|in)\s+(\S+(?: \S+)?)$/i.exec(t);
  if (m && Lexicon.langFor(m[2]) && Lexicon.langFor(m[3]))
    return { text: m[1], from: Lexicon.langFor(m[2]), to: Lexicon.langFor(m[3]) };
  m = /^(.*?)\s+(?:to|into|in)\s+(\S+(?: \S+)?)$/i.exec(t);
  if (m && m[1].trim() !== "" && Lexicon.langFor(m[2])) return { text: m[1], from: null, to: Lexicon.langFor(m[2]) };
  m = /^(.*?)\s+(?:to|into|in)\s+(\S+)$/i.exec(t);
  if (m && m[1].trim() !== "" && Lexicon.langFor(m[2])) return { text: m[1], from: null, to: Lexicon.langFor(m[2]) };
  return { text: t, from: null, to: null };
}
function parseLexi(query) {
  const raw = String(query || "").replace(/^\s+/, "");
  const q = raw.trim().replace(/[?!.]+$/, "");
  let m;
  if ((m = /^(?:define|def)(?:\s+(.*))?$/i.exec(raw))) {
    const rest = String(m[1] || "").trim();
    const d = /^(.+?)\s+in\s+(\S+(?: \S+)?)$/i.exec(rest);
    if (d && Lexicon.langFor(d[2]) && Lexicon.langFor(d[2]).en) return { mode: "dict", word: d[1], lang: Lexicon.langFor(d[2]) };
    return { mode: "dict", word: rest, lang: null };
  }
  if ((m = /^(?:translate|tr)(?:\s+(.*))?$/i.exec(raw)))
    return Object.assign({ mode: "trans" }, lexiTarget(m[1] || ""));
  if ((m = /^how (?:do (?:you|i)|to|would you|can i) say (.+?) in (\S+(?: \S+)?)$/i.exec(q)) && Lexicon.langFor(m[2]))
    return { mode: "trans", text: m[1].replace(/^["“]|["”]$/g, ""), from: null, to: Lexicon.langFor(m[2]) };
  if ((m = /^(?:what(?:'?s| is) )?(.+?) in (\S+(?: \S+)?)$/i.exec(q)) && Lexicon.langFor(m[2])
      && words(m[1]) <= LEXI_WORDS && !/\d/.test(m[1]))
    return { mode: "trans", text: m[1].replace(/^["“]|["”]$/g, ""), from: null, to: Lexicon.langFor(m[2]) };
  if ((m = /^(?:(?:what(?:'?s| is) )?(?:the )?(?:meaning|definition) of|define:?) (.+)$/i.exec(q)) && words(m[1]) <= 3)
    return { mode: "dict", word: m[1], lang: null };
  if ((m = /^what does (.+?) mean$/i.exec(q)) && words(m[1]) <= 3)
    return { mode: "dict", word: m[1].replace(/^["“]|["”]$/g, ""), lang: null };
  if ((m = /^(.+?) (?:meaning|definition|means)$/i.exec(q)) && words(m[1]) <= 3)
    return { mode: "dict", word: m[1], lang: null };
  return null;
}

// ── SETTINGS (2026-11-01) ─────────────────────────────────────────────────
// Oracle's pages and rows, found from the line ("bluetooth", "font size",
// "dark mode") by Oracle's own filter (oracle.js matches: label, help, key,
// alias): return opens Oracle on that page, at that row. In any line only
// the ones whose NAME starts with a word of it, three at most, so a search
// for an app is not buried; "settings …" lists every match.
const SETTINGS_ANY = 3;
// What each row is searched by, worked out once per schema (it is rebuilt
// only when Oracle's settings change) instead of on every key
let settingsIndexOf = null, settingsIndex = null;
function settingsIndexFor(schema, pages) {
  if (settingsIndexOf === schema && settingsIndex) return settingsIndex;
  const out = [];
  for (const sp of schema || []) {
    if (sp.type === "info" || !pages[sp.section] || !sp.label) continue;
    out.push({ sp, label: sp.label.toLowerCase(), words: " " + sp.label.toLowerCase(),
      hay: (String(sp.label || "") + " " + String(sp.help || "") + " " + String(sp.key || "") + " "
        + String(sp.section || "") + " " + String(sp.alias || "")).toLowerCase() });
  }
  settingsIndexOf = schema;
  settingsIndex = out;
  return out;
}
function settingsRows(schema, sections, query, scoped) {
  const q = String(query || "").trim();
  if (!scoped && q.length < 3) return [];
  const pages = {};
  for (const p of sections || []) pages[p.id] = p;
  const named = (label) => matchRank({ text: label }, q.toLowerCase());
  const out = [];
  // the pages themselves first: "display", "fonts"
  for (const p of sections || []) {
    const k = q === "" ? 0 : named(p.label);
    if (q !== "" && (k < 0 || (!scoped && k > 1))) continue;
    out.push({ kind: "setting", key: "set:" + p.id, page: p.id, spec: "", rank: k, text: p.label, label: p.label,
      sub: "Settings page", glyph: p.icon || "\uF013", section: "Settings" });
  }
  const ql = q.toLowerCase();
  const qwords = ql.split(/\s+/).filter((w) => w !== "");
  const first = qwords[0] || "";
  // Oracle's own rule (oracle.js matches): every word somewhere in the row
  const hits = (x) => qwords.every((w) => x.hay.indexOf(w) >= 0);
  for (const x of settingsIndexFor(schema, pages)) {
    const sp = x.sp;
    // in any line: the name starts with the line, or with a word of it and
    // Oracle's filter takes the rest ("font size" finds Font size)
    const k = x.label.startsWith(ql) ? 0 : x.words.indexOf(" " + ql) >= 0 ? 1 : -1;
    const wordStart = x.words.indexOf(" " + first) >= 0 && hits(x);
    if (scoped ? (q !== "" && !hits(x)) : !((k >= 0 && k <= 1) || wordStart)) continue;
    // a row drawn inside another (the Font row's size) opens at that one
    out.push({ kind: "setting", key: "set:" + sp.key, page: sp.section, spec: sp.within || sp.key,
      rank: k >= 0 && k <= 1 ? k : 2,
      text: sp.label, label: sp.label, sub: pages[sp.section].label, glyph: pages[sp.section].icon || "\uF013",
      section: "Settings" });
  }
  out.sort((a, b) => a.rank - b.rank);
  return out.slice(0, scoped ? 60 : SETTINGS_ANY);
}

// ── THE STORE (2026-11-01) ────────────────────────────────────────────────
// Ceres' catalog (ceres-store list), ranked by Ceres' own search (store.js):
// "store …" or "install …" lists the apps; return opens the app's page in
// Ceres, and its actions install it there.
function storeRows(apps, query, glyphOf) {
  const q = String(query || "").trim();
  if (q === "") return [];
  return Store.search(apps || [], q).slice(0, 40).map((a) => ({ kind: "storeapp", key: "store:" + a.key,
    app: a.key, pkg: a.pkg || "", source: a.source || "", installed: !!a.installed, text: a.name, label: a.name,
    sub: a.summary || "", glyph: (glyphOf ? glyphOf([a.pkg, a.name]) : "") || "\uF187", section: "Store" }));
}

// ── PACKAGES (2026-11-01) ─────────────────────────────────────────────────
// "pkg …" (user: "store doesn't list everything, and certainly doesn't cover
// the AUR"): every repo package and the AUR, as Ceres' Packages tab searches
// them (scripts/ceres.sh search; ceres.js parseRows rows in). Return asks
// Ceres to install it — or remove it, installed — on its own confirm sheet.
function packageRows(found) {
  return (found || []).slice(0, 60).map((p) => ({ kind: "package", key: "pkg:" + p.name, pkg: p,
    installed: p.installed, aur: p.aur, text: p.name, label: p.name,
    sub: (p.aur ? "AUR" : p.repo) + (p.version ? " \u00B7 " + p.version : ""),
    glyph: p.installed ? "\uF05D" : "\uF187", section: "Packages" }));
}

// ── A CALENDAR EVENT IN PLAIN WORDS (2026-11-01) ──────────────────────────
// "event lunch with sam friday 1pm @ Luigi's": Chronos' own reading of a
// line (chronos.js parseNatural — the day, the time, a length, the place),
// shown as the row says it will be kept; return adds it (Chronos.addQuick).
function eventRow(words, todayIso, now) {
  const w = String(words || "").trim();
  if (w === "") return null;
  const q = Chr.parseNatural(w, todayIso, now);
  if (q.error) return { kind: "newevent", key: "newevent", text: w, label: q.error, sub: "", bad: true,
    glyph: "\uF073", section: "" };
  const d = Chr.dateOf(q.iso);
  const when = (d ? Chr.longDay(d) : q.iso) + (q.allDay ? " \u00B7 all day"
    : " \u00B7 " + q.start.slice(11) + " \u2013 " + q.end.slice(11));
  return { kind: "newevent", key: "newevent", text: w, label: q.title, sub: when + (q.location ? " \u00B7 " + q.location : ""),
    glyph: "\uF073", section: "" };
}

// ── CLIO'S NOTES (2026-11-01) ─────────────────────────────────────────────
// "notes …" searches the notebook by Clio's own scoring (notes.js terms and
// score: the title counting most, #tags, is:/has: filters); with nothing
// after it, the latest. Once the notebook is read, any line also shows the
// few whose title the line starts. "note …" offers a new note of the words.
const NOTE_GLYPH = "\uE678", ENTRY_GLYPH = "\uF02D";
function noteRows(notes, query, scoped) {
  const q = String(query || "").trim();
  if (!scoped && q.length < 3) return [];
  const t = Notes.terms(q);
  const hits = [];
  for (const n of notes || []) {
    if (n.deleted > 0) continue;
    const s = q === "" ? 1 : Notes.score(n, t);
    if (s <= 0 || (!scoped && s < 41)) continue;
    hits.push({ n, s });
  }
  hits.sort((a, b) => (b.s - a.s) || ((b.n.modified || 0) - (a.n.modified || 0)));
  return hits.slice(0, scoped ? 40 : 3).map((h) => {
    const d = h.n.d || Notes.derive(h.n);
    const locked = !!(h.n.sealed || h.n.locked);
    return { kind: "note", key: "note:" + h.n.id, id: h.n.id, text: d.title || "Untitled",
      label: d.title || "Untitled", sub: locked ? "Locked" : String(d.preview || "").slice(0, 120),
      glyph: h.n.kind === "entry" ? ENTRY_GLYPH : NOTE_GLYPH, entry: h.n.kind === "entry", section: "Notes" };
  });
}
// "note buy milk": the row that makes it
function newNoteRow(words) {
  const w = String(words || "").trim();
  if (w === "") return null;
  return { kind: "newnote", key: "newnote", text: w, label: "New note \u201C" + (w.length > 60 ? w.slice(0, 59) + "\u2026" : w) + "\u201D",
    sub: "Clio", glyph: NOTE_GLYPH, section: "" };
}

// ── GLYPHS YOU USED (2026-11-01) ───────────────────────────────────────────
// The emoji and nerd glyphs last pasted or copied, newest first, each set
// its own list: they lead the strips ("Recently used") and lead a search.
//   { "emoji": ["👍", …], "nerd": ["", …] }
const RECENT_GLYPHS = 22;
function glyphsPath() {
  return Paths.cacheDir() + "/cynosure-glyphs.json";
}
function parseGlyphs(text) {
  try {
    const j = JSON.parse(String(text || "") || "{}");
    const list = (x) => Array.isArray(x) ? x.filter((c) => typeof c === "string" && c !== "").slice(0, RECENT_GLYPHS) : [];
    return { emoji: list(j.emoji), nerd: list(j.nerd) };
  } catch (e) { return { emoji: [], nerd: [] }; }
}
function addGlyph(recent, ch, nerd) {
  const r = recent || { emoji: [], nerd: [] };
  const k = nerd ? "nerd" : "emoji", c = String(ch || "");
  const out = { emoji: (r.emoji || []).slice(), nerd: (r.nerd || []).slice() };
  if (c === "") return out;
  out[k] = [c].concat(out[k].filter((x) => x !== c)).slice(0, RECENT_GLYPHS);
  return out;
}

// ── HOTKEYS (2026-11-01) ───────────────────────────────────────────────────
// Raycast's: a chord of your own for an app, a command, a file, a script or
// a link, set from its actions. Kept as JSON beside the aliases ({ chord,
// row }, the row as it was when the keys were given), and written out for
// hyprland as hotkeys.lua in ~/.config/zenworks/hypr/lua, which binds.lua
// reads: each chord calls `qs ipc call Cynosure hotkey '<chord>'`.
const HOTKEY_KINDS = { app: true, shell: true, file: true, script: true, link: true, hist: true };
function hotkeysPath() {
  return Paths.dataDir() + "/cynosure-hotkeys.json";
}
function hotkeysLuaPath() {
  return Paths.configDir() + "/zenworks/hypr/lua/hotkeys.lua";
}
function parseHotkeys(text) {
  try {
    const j = JSON.parse(String(text || "") || "[]");
    return Array.isArray(j) ? j.filter((h) => h && typeof h.chord === "string" && h.chord !== ""
      && h.row && HOTKEY_KINDS[h.row.kind]) : [];
  } catch (e) { return []; }
}
function serializeHotkeys(list) {
  return JSON.stringify(list || [], null, 2) + "\n";
}
// a row as it is known again: its kind and its key (a file by its path)
function hotkeyTarget(row) {
  return row ? row.kind + "\u0000" + (row.kind === "file" ? row.path : row.key) : "";
}
function hotkeyOf(list, row) {
  const t = hotkeyTarget(row);
  const h = (list || []).find((x) => hotkeyTarget(x.row) === t);
  return h ? h.chord : "";
}
// what is kept of a row: the plain data that runs it, nothing drawn
function hotkeyRow(row) {
  const out = {};
  for (const k of ["kind", "key", "id", "label", "text", "path", "isDir", "url", "raw", "glyph", "action", "script", "arg"])
    if (row[k] !== undefined) out[k] = row[k];
  return out;
}
// this chord for this row: whatever had the chord, and whatever this row had
// before, let go
function setHotkey(list, chord, row) {
  const t = hotkeyTarget(row);
  const rest = (list || []).filter((h) => h.chord !== chord && hotkeyTarget(h.row) !== t);
  return chord === "" ? rest : rest.concat([{ chord, row: hotkeyRow(row) }]);
}
function dropHotkey(list, row) {
  const t = hotkeyTarget(row);
  return (list || []).filter((h) => hotkeyTarget(h.row) !== t);
}
function hotkeyLabel(h) {
  return "Cynosure: " + String((h.row && (h.row.label || h.row.text)) || "");
}
function luaQuote(s) {
  return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, " ") + "\"";
}
function renderHotkeysLua(list) {
  const lines = [
    "-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐",
    "-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐",
    "-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘",
    "-- https://github.com/kbuckleys/",
    "",
    "-- Cynosure's hotkeys, written by it (shift return on a row, Set hotkey):",
    "-- binds.lua binds each chord to `qs ipc call Cynosure hotkey '<chord>'`.",
    "",
    "return {"
  ];
  for (const h of list || [])
    lines.push("\t{ chord = " + luaQuote(h.chord) + ", label = " + luaQuote(hotkeyLabel(h)) + " },");
  lines.push("}");
  return lines.join("\n") + "\n";
}

// ── ALIASES (2026-11-01) ───────────────────────────────────────────────────
// Your own word for an app, a command or a file ("ff" for Firefox), set from
// its actions (ctrl k): typed, it is the first row. Kept with your data, not
// the cache — a word you chose is not something to lose to a cache clear.
//   { "ff": { kind: "app", key: "Firefox", label: "Firefox" },
//     "cv": { kind: "file", key: "/home/…/cv.pdf", path: "/home/…/cv.pdf", label: "cv.pdf" } }
function aliasPath() {
  return Paths.dataDir() + "/cynosure-aliases.json";
}
// ── QUICK LINKS (2026-11-01) ───────────────────────────────────────────────
// A word, then what to look for: "gh zenworks" searches GitHub, "yt lofi"
// YouTube; the word alone and a space opens the site. `{q}` in the url is
// where the words go. Yours (cynosure-links.json, beside the aliases) are
// made with "New quick link" and take a built-in's word over.
const QUICKLINKS = [
  { word: "web", name: "the web", url: "https://duckduckgo.com/?q={q}", home: "https://duckduckgo.com", glyph: "\uF0AC" },
  { word: "g", name: "Google", url: "https://www.google.com/search?q={q}", home: "https://www.google.com", glyph: "\uF1A0" },
  { word: "ddg", name: "DuckDuckGo", url: "https://duckduckgo.com/?q={q}", home: "https://duckduckgo.com", glyph: "\uF0AC" },
  { word: "gh", name: "GitHub", url: "https://github.com/search?q={q}", home: "https://github.com", glyph: "\uF09B" },
  { word: "yt", name: "YouTube", url: "https://www.youtube.com/results?search_query={q}", home: "https://www.youtube.com", glyph: "\uF167" },
  { word: "w", name: "Wikipedia", url: "https://en.wikipedia.org/w/index.php?search={q}", home: "https://en.wikipedia.org", glyph: "\uF266" },
  { word: "aw", name: "the Arch Wiki", url: "https://wiki.archlinux.org/index.php?search={q}", home: "https://wiki.archlinux.org", glyph: "\uF303" },
  { word: "aur", name: "the AUR", url: "https://aur.archlinux.org/packages?K={q}", home: "https://aur.archlinux.org", glyph: "\uF303" },
  { word: "arch", name: "Arch packages", url: "https://archlinux.org/packages/?q={q}", home: "https://archlinux.org/packages/", glyph: "\uF303" },
  { word: "r", name: "Reddit", url: "https://www.reddit.com/search/?q={q}", home: "https://www.reddit.com", glyph: "\uF281" },
  { word: "so", name: "Stack Overflow", url: "https://stackoverflow.com/search?q={q}", home: "https://stackoverflow.com", glyph: "\uF16C" },
  { word: "maps", name: "the map", url: "https://www.openstreetmap.org/search?query={q}", home: "https://www.openstreetmap.org", glyph: "\uF279" },
  { word: "mdn", name: "MDN", url: "https://developer.mozilla.org/en-US/search?q={q}", home: "https://developer.mozilla.org", glyph: "\uF13B" },
  { word: "imdb", name: "IMDb", url: "https://www.imdb.com/find/?q={q}", home: "https://www.imdb.com", glyph: "\uF2D8" }
];
function linksPath() {
  return Paths.dataDir() + "/cynosure-links.json";
}
function parseLinks(text) {
  try {
    const j = JSON.parse(text || "[]");
    return Array.isArray(j) ? j.filter((l) => l && l.word && /^https?:\/\//i.test(String(l.url || ""))) : [];
  } catch (e) { return []; }
}
function serializeLinks(list) {
  return JSON.stringify(list || [], null, 2) + "\n";
}
// the built-ins with yours over them (yours marked `own`)
function allLinks(own) {
  const out = [];
  const mine = {};
  for (const l of own || []) mine[l.word] = true;
  for (const l of QUICKLINKS) if (!mine[l.word]) out.push(l);
  for (const l of own || []) out.push(Object.assign({ glyph: "\uF0C1" }, l, { own: true }));
  return out;
}
// the site's name, said from its address: "github.com" → "Github"
function siteName(url) {
  const m = /^https?:\/\/(?:www\.)?([^/:?#]+)/i.exec(String(url || ""));
  if (!m) return "the link";
  const host = m[1].split(".");
  const base = host.length > 1 ? host[host.length - 2] : host[0];
  return base.charAt(0).toUpperCase() + base.slice(1);
}
// "word https://…{q}…" typed into "New quick link": the link, or why not
function readLink(line) {
  const m = /^\s*(\S+)\s+(\S+)\s*$/.exec(String(line || ""));
  if (!m) return { problem: "A word, a space, then the address" };
  const word = m[1].toLowerCase();
  const p = aliasProblem(word);
  if (p) return { problem: p };
  if (!/^https?:\/\//i.test(m[2])) return { problem: "The address starts with https://" };
  return { link: { word, name: siteName(m[2]), url: m[2] } };
}
function linkUrl(l, rest) {
  const q = String(rest || "").trim();
  if (q === "") return l.home || (/^https?:\/\/[^/]+/i.exec(l.url) || [l.url])[0];
  return l.url.indexOf("{q}") >= 0 ? l.url.split("{q}").join(encodeURIComponent(q)) : l.url;
}
function linkRow(l, rest, section) {
  const q = String(rest || "").trim();
  return { kind: "link", key: "link:" + l.word, word: l.word, own: !!l.own, url: linkUrl(l, q),
    glyph: l.glyph || "\uF0C1", text: q || l.name,
    label: q ? "Search " + l.name + " for \u201C" + q + "\u201D" : "Open " + l.name,
    sub: (/^https?:\/\/(?:www\.)?([^/?#]+)/i.exec(l.url) || ["", ""])[1], section: section || "Quick link" };
}
// "gh zenworks": the link the line's first word is, with the rest
function linkFor(links, query) {
  const m = /^\s*(\S+)\s+(.*)$/.exec(String(query || ""));
  if (!m) return null;
  const word = m[1].toLowerCase();
  const l = (links || []).find((x) => x.word === word);
  return l ? linkRow(l, m[2]) : null;
}
// every link as a command of its own: "Search GitHub", its word on it
function linkActions(links) {
  // named site first ("GitHub search"), so typing the site finds it first
  const site = (n) => { const t = String(n).replace(/^the /i, ""); return t.charAt(0).toUpperCase() + t.slice(1); };
  return (links || []).map((l) => ({ name: site(l.name) + " search", glyph: l.glyph || "\uF0C1",
    keys: l.word + " " + l.name + " quick link search web", line: l.word + " ", alias: l.word }));
}

// the words Cynosure answers to itself: a panel's ("cb …") or the calculator's
const RESERVED = ["f", "cb", "calc", "def", "define", "tr", "translate", "em", "nf", "pw", "win", "settings",
  "store", "install", "notes", "note", "pkg", "event"];
function aliasProblem(word) {
  const w = String(word || "").trim().toLowerCase();
  if (w === "") return "";
  if (/\s/.test(w)) return "An alias is one word";
  if (RESERVED.indexOf(w) >= 0) return "\u201C" + w + "\u201D is one of Cynosure's own words";
  return "";
}
function parseAliases(text) {
  try {
    const j = JSON.parse(text || "{}");
    return j && typeof j === "object" && !Array.isArray(j) ? j : {};
  } catch (e) { return {}; }
}
function serializeAliases(map) {
  return JSON.stringify(map || {}, null, 2) + "\n";
}
// what an alias points at, as a row is known by
function aliasTarget(row) {
  return row.kind + "\u0000" + (row.kind === "file" ? row.path : row.key);
}
// the map with `word` for this row, and no other word for it
function setAlias(map, word, row) {
  const out = dropAlias(map, row);
  const w = String(word || "").trim().toLowerCase();
  if (w === "") return out;
  out[w] = { kind: row.kind, key: row.kind === "file" ? row.path : row.key, label: row.label || row.text || "" };
  if (row.kind === "file") out[w].path = row.path;
  return out;
}
function dropAlias(map, row) {
  const out = {};
  const t = aliasTarget(row);
  for (const w in map || {}) {
    const a = map[w];
    if (a.kind + "\u0000" + a.key !== t) out[w] = a;
  }
  return out;
}
// the rows with their aliases on them (copies where one is set)
function withAliases(rows, map) {
  const by = {};
  for (const w in map || {}) by[map[w].kind + "\u0000" + map[w].key] = w;
  return (rows || []).map((r) => {
    const w = by[r.kind + "\u0000" + r.key];
    return w ? Object.assign({}, r, { alias: w }) : r;
  });
}
// the aliased files whose word starts the line, as file rows wearing it
function aliasFiles(map, query, home, glyphOf) {
  const q = String(query || "").trim().toLowerCase();
  if (q === "") return [];
  const out = [];
  for (const w in map || {}) {
    const a = map[w];
    if (a.kind !== "file" || !w.startsWith(q)) continue;
    const row = fileRows([a.path], home, glyphOf)[0];
    out.push(Object.assign(row, { alias: w }));
  }
  return out;
}

function shell() {
  return Quickshell.env("SHELL") || "/bin/bash";
}

const ICON_T = "\uEA85";
const ICON_P = "\uEB7F";
const ICON_B = "\uEE23";

// ── THE SHELL'S OWN VERBS ─────────────────────────────────────────────────
// Every component already answers `qs ipc call`, so the launcher can reach
// all of them without knowing anything about them: one line per verb, found
// by its name or any of its keys, ranked by the same frecency as the apps.
//
// The session verbs (erebus' old five, which live here now) carry `confirm`:
// they open the picker as "Reboot?" with Back already selected, so a typed
// "re" and a couple of returns is never a reboot.
//
// `sh` is a shell line; `{dir}` in it is the shell's own directory, already
// quoted — write it bare — and `{session}` the logind session this shell runs
// in.
//
// `needs` names a live flag the popup passes in (as `state` does): while it
// is not set the row is not offered at all — Wi-Fi on a machine without it
// is a row that can only fail (2026-10-21).
//
// `view` marks a verb that opens one of the quick panels Cynosure fronts
// for. It is handed the panel in the shell (shell.qml's `views`) rather than
// by its `ipc`, so the pill passes straight from one to the other and
// whatever was typed after its `alias` arrives in the panel's own field:
// "cb invoice" is the clipboard, already searching for "invoice". `say` is
// that row's verb.
const SHELL_ACTIONS = [
  { name: "Lock screen", glyph: "\uF456", keys: "lock cerberus", sh: "sleep 0.35 && qs ipc call Cerberus lock" },
  { name: "Log out", glyph: "\uDB81\uDF43", keys: "logout session exit quit", sh: "hyprshutdown -t 'Logging out…' -p 'loginctl terminate-session {session}'", confirm: true },
  { name: "Suspend", glyph: "\uDB82\uDD04", keys: "sleep standby", sh: "systemctl suspend", confirm: true },
  { name: "Reboot", glyph: "\uF021", keys: "restart", sh: "hyprshutdown -t 'Rebooting…' -p 'systemctl reboot'", confirm: true },
  { name: "Shutdown", glyph: "\u23FB", keys: "shutdown power off poweroff halt", sh: "hyprshutdown -t 'Shutting down…' -p 'systemctl poweroff'", confirm: true },
  { name: "Settings", glyph: "\uF013", keys: "oracle preferences options config", ipc: "Oracle open" },
  { name: "Check for updates", glyph: "\uF2F1", keys: "ceres upgrade refresh sync", ipc: "Ceres check" },
  { name: "Store", glyph: "\uDB83\uDD68", keys: "ceres store apps app store packages install remove paru pacman aur flatpak flathub", ipc: "Ceres window store" },
  { name: "Updates", glyph: "\uF062", keys: "ceres upgrade packages", ipc: "Ceres window updates" },
  { name: "Package history", glyph: "\uF1DA", keys: "ceres downgrade rollback log", ipc: "Ceres window history" },
  { name: "Package maintenance", glyph: "\uF0AD", keys: "ceres clean cache orphans pacnew", ipc: "Ceres window maintenance" },
  { name: "Files", glyph: "\uF114", keys: "terminus file manager directories folders", ipc: "Terminus toggle" },
  { name: "Find files", glyph: "\uF002", keys: "artemis search finder locate", ipc: "Artemis toggle",
    view: "artemis", alias: "f", say: "Find files named" },
  { name: "Background", glyph: "\uF03E", keys: "picasso background wallpaper", ipc: "Picasso toggle" },
  { name: "Pick a color", glyph: "\u{F020A}", keys: "picasso color colour picker eyedropper hex palette", sh: "sleep 0.35 && qs ipc call Picasso pick" },
  { name: "Measure on screen", glyph: "\u{F046D}", keys: "picasso ruler measure pixels distance size", sh: "sleep 0.35 && qs ipc call Picasso measure" },
  { name: "New note", glyph: "\uF24A", keys: "clio sticky desktop", ipc: "Clio add" },
  { name: "New journal entry", glyph: "\u{F0B64}", keys: "clio journal diary write reflect mood", ipc: "Clio journal" },
  { name: "Today's journal entry", glyph: "\u{F00F6}", keys: "clio journal today daily diary", ipc: "Clio today" },
  { name: "Quick note", glyph: "\u{F140B}", keys: "clio capture jot quick note inbox", ipc: "Clio capture" },
  { name: "Notifications", glyph: "\uF0F3", keys: "howler bell history", ipc: "Howler toggle" },
  { name: "Clear notifications", glyph: "\uF1F6", keys: "howler bell dismiss", ipc: "Howler clear" },
  // `line` is typed into the field rather than run; `inline` is one of
  // Cynosure's own (see CynosurePopup.runInline)
  { name: "Clipboard pictures", glyph: "\uF03E", keys: "folio clipboard images screenshots pics copied", line: "cb pictures" },
  { name: "New script", glyph: "\uF489", keys: "script command raycast shell bash python automate", inline: "newScript" },
  { name: "Scripts folder", glyph: "\uF07C", keys: "scripts commands directory", inline: "scriptsDir" },
  { name: "New quick link", glyph: "\uF0C1", keys: "quick link url bookmark search engine keyword web site", inline: "newLink" },
  { name: "New snippet", glyph: "\uEB66", keys: "folio snippet text expand write template paste again", inline: "newSnippet" },
  { name: "Clipboard", glyph: "\uF0EA", keys: "folio paste history copy", ipc: "Folio toggle",
    view: "folio", alias: "cb", say: "Search the clipboard for" },
  { name: "Passwords", glyph: "\uEB11", keys: "calypso pass login totp quick access", ipc: "Calypso toggle",
    view: "calypso", alias: "pw", say: "Find the login" },
  { name: "Password manager", glyph: "\uEB11", keys: "calypso vault bitwarden 1password proton keepass gopass accounts", ipc: "Calypso open" },
  { name: "Lock passwords", glyph: "\uF023", keys: "calypso lock vault", ipc: "Calypso lock" },
  { name: "Calculator", glyph: "\uF1EC", keys: "metis math calc", ipc: "Cynosure view metis",
    view: "metis", alias: "calc", say: "Calculate" },
  { name: "Dictionary", glyph: "\uF02D", keys: "lexi define word", ipc: "Lexi toggle",
    view: "lexi:dict", alias: "def", say: "Define" },
  { name: "Translate", glyph: "\uF1AB", keys: "lexi language", ipc: "Lexi translate",
    view: "lexi:trans", alias: "tr", say: "Translate" },
  { name: "Emoji", glyph: "\uF118", keys: "ideo emoticon smiley", ipc: "Ideo emoji",
    view: "ideo:emoji", alias: "em", say: "Find emoji" },
  { name: "Nerd glyphs", glyph: "\uF031", keys: "ideo icons font symbols", ipc: "Ideo nerd",
    view: "ideo:nerd", alias: "nf", say: "Find nerd glyphs" },
  { name: "Sound & system", glyph: "\uF028", keys: "zeus volume audio mixer cpu memory monitor", ipc: "Zeus toggle" },
  { name: "Calendar & weather", glyph: "\uF073", keys: "chronos clock date forecast", ipc: "Chronos toggle" },
  { name: "Calendar", glyph: "\u{EAB0}", keys: "chronos calendar window month week events schedule agenda", ipc: "Calendar open ''" },
  { name: "New event", glyph: "\u{F00F3}", keys: "chronos calendar event appointment meeting add", ipc: "Calendar add ''" },
  // `choose: "timer"`: with more than one idle timer the popup asks which
  // one in its picker (see timerChoices) instead of running `ipc` blind.
  { name: "Start timer", glyph: "\uF017", keys: "chronos pomodoro focus countdown", ipc: "Chronos start", choose: "timer" },
  { name: "Stop timer", glyph: "\uF28D", keys: "chronos pomodoro halt countdown", ipc: "Chronos halt" },
  // A toggle in socordia (forceAwake flips), so the row says what pressing it
  // does: Caffeinate while the screen may sleep, Decaffeinate while it is
  // held awake. Not `Socordia release`: that drops logind's delay lock before
  // a suspend, an escape hatch rather than the way back from keeping awake.
  // `state` names a live flag the popup passes in; while it is set the row
  // wears `on` instead. `name` stays the frecency key in both states.
  { name: "Caffeinate", glyph: "\u{F06CA}", keys: "socordia keep awake idle inhibit caffeine coffee decaf sleep",
    ipc: "Socordia awake", state: "awake", on: { name: "Decaffeinate", glyph: "\u{F0FAB}" } },
  { name: "Reload shell", glyph: "\uF01E", keys: "quickshell restart qs", sh: "{dir}/scripts/restart.sh" },

  // ── the 10-20 apps ──
  // control hub (hermes): the window, and its switches where there is one
  { name: "Grayscale screen", glyph: "\u{F0301}", keys: "hermes color filter grayscale greyscale monochrome focus", ipc: "Hermes filter gray" },
  { name: "Control Hub", glyph: "\u{F1542}", keys: "hermes network wifi wi-fi ethernet bluetooth vpn display brightness settings", ipc: "Hermes window ''" },
  { name: "Printers & scanners", glyph: "\u{F042A}", keys: "hermes printer printing print scanner scan cups", ipc: "Hermes window printers" },
  { name: "Night light", glyph: "\u{F0594}", keys: "hermes hyprsunset warm blue light evening", ipc: "Hermes night",
    needs: "nightReady", state: "night", on: { name: "Night light off", glyph: "\u{F00DF}" } },
  { name: "Wi-Fi off", glyph: "\u{F05AA}", keys: "hermes wireless network radio", ipc: "Hermes wifi",
    needs: "wifiReady", state: "wifiOff", on: { name: "Wi-Fi on", glyph: "\u{F05A9}" } },
  { name: "Bluetooth off", glyph: "\u{F00B2}", keys: "hermes radio headphones", ipc: "Hermes bluetooth",
    needs: "btReady", state: "btOff", on: { name: "Bluetooth on", glyph: "\u{F00AF}" } },
  // argus: recording, through the same ZenRecord the binds use; after the
  // launcher has gone, so it is not in the picture
  { name: "Record the screen", glyph: "\u{F044B}", keys: "argus recording video capture screencast", sh: "sleep 0.35 && hyprctl repl 'ZenRecord(\"full\")'" },
  { name: "Record a region", glyph: "\u{F0A6D}", keys: "argus recording video capture area selection", sh: "sleep 0.35 && hyprctl repl 'ZenRecord(\"region\")'" },
  { name: "Record a window", glyph: "\u{F0614}", keys: "argus recording video capture", sh: "sleep 0.35 && hyprctl repl 'ZenRecord(\"window\")'" },
  { name: "Stop recording", glyph: "\u{F0667}", keys: "argus recording end finish", sh: "hyprctl repl 'ZenRecord(\"stop\")'" },
  { name: "Cut the last recording", glyph: "\u{F0190}", keys: "argus trim edit gif webm mp4 video", ipc: "Argus last" },
  // minerva
  { name: "Continue reading", glyph: "\u{F05DA}", keys: "minerva book ebook pdf epub reader", ipc: "Minerva last" },
  { name: "Library", glyph: "\u{F03D2}", keys: "minerva books reading pdf epub", ipc: "Minerva library" },
  // hestia
  { name: "Services", glyph: "\u{F08D6}", keys: "hestia systemd systemctl daemons units", ipc: "Hestia open system" },
  { name: "System journal", glyph: "\u{F09EE}", keys: "hestia logs journalctl errors", ipc: "Hestia journal ''" },
  { name: "What's wrong", glyph: "\u{F05D6}", keys: "hestia failed services errors broken overview health", ipc: "Hestia open overview" },
  // stylus
  { name: "Write an image to a drive", glyph: "\u{F0D13}", keys: "stylus iso usb flash burn etcher rufus sd card bootable dd", ipc: "Stylus open ''" },
  // kairos
  { name: "This week's screen time", glyph: "\u{F0128}", keys: "kairos screen time usage week apps hours", ipc: "Kairos open week" },
  { name: "Keyboard shortcuts", glyph: "\u{F030C}", keys: "keys keybinds binds cheat sheet hotkeys shortcuts", sh: "sleep 0.3 && qs ipc call Keys open" },
];

// The frecency key, kept apart from app names: an app called "Files" and the
// shell's Files are two rows with two counts.
function actionKey(a) {
  return "shell:" + a.name;
}

// The idle timers as picker rows, keyed by their index in Chronos.timers.
// Running ones are left out: starting them again would do nothing.
function timerChoices(timers) {
  const out = [];
  for (let i = 0; i < (timers || []).length; ++i) {
    const t = timers[i];
    if (t.running) continue;
    out.push({ key: "timer:" + i, label: "  " + t.label + " " + t.minutes + "m" });
  }
  return out;
}

function actionCommand(a, dir, session) {
  // {dir} is quoted HERE, whole, rather than wrapped in quotes in the table:
  // hand-written '…' around it broke on a directory with a quote in it
  if (a.sh) return a.sh.split("{dir}").join(Strings.shellQuote(dir))
    .split("{session}").join(session || "");
  return "qs ipc call " + a.ipc;
}

const HIST_MAX = 200;

function stripIcon(entry) {
  let rest = entry;
  for (const ic of [ICON_T, ICON_P]) {
    if (rest.startsWith(ic)) {
      rest = rest.slice(ic.length);
      break;
    }
  }
  return rest;
}

function stripPrefix(s) {
  const idx = s.indexOf("  ");
  return idx >= 0 ? s.slice(idx + 2) : s;
}

function parseHistory(text) {
  const lines = [];
  if (!text) return lines;
  for (const line of text.split("\n")) {
    if (line.trim() === "") continue;
    if (stripIcon(line).trim() === "") continue;
    lines.push(line);
  }
  return lines;
}

function parseFreq(text) {
  const map = {};
  if (!text) return map;
  for (const line of text.split("\n")) {
    const m = line.match(/^(.*)=(\d+)$/);
    if (m && m[1] !== "") map[m[1]] = parseInt(m[2], 10);
  }
  return map;
}

// the Exec line's field codes gone, and %% the literal % it stands for —
// in one pass, so "%%f" is "%f" and not nothing (2026-10-23: a date format
// like `date +%%H` reached the shell as `+%%H`)
function stripFieldCodes(exec) {
  return exec.replace(/%([%fFuUdDnNickvm])/g, (m, c) => (c === "%" ? "%" : "")).replace(/\s+$/, "");
}

function getApps(modelValues) {
  const apps = [];
  const seen = {};
  for (const v of modelValues) {
    if (!v) continue;
    const name = (v.name || "").trim();
    const exec = stripFieldCodes(v.exec || "").trim();
    const id = v.id || "";
    if (!name || !exec) continue;
    const key = name.toLowerCase();
    if (seen[key]) continue;
    seen[key] = true;
    apps.push({ name, exec, id, icon: v.icon || "", terminal: !!v.terminal, words: String(v.words || ""),
      generic: String(v.generic || "").trim() });
  }
  apps.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  return apps;
}

// A toggle's row wears its state — Caffeinate while it is off, Decaffeinate
// while it is on — or you cannot tell which way it is.
function actionFace(a, states) {
  return a.state && a.on && (states || {})[a.state] ? a.on : a;
}

// "glyph  label" split at its first double space — the history lines and the
// picker labels are stored that way. Drawn as two pieces: in rich text the
// double space collapses to one and the glyph sits on the word.
function splitGlyph(s) {
  const t = String(s);
  const idx = t.indexOf("  ");
  return idx > 0 ? { glyph: t.slice(0, idx), label: t.slice(idx + 2) } : { glyph: "", label: t.trim() };
}

// `glyphOf` is morpheus' appGlyph — handed in rather than imported, so this
// file stays loadable on its own. An app nothing claims shows no glyph at all.
function buildRows(apps, histLines, freq, actions, states, glyphOf) {
  const appNames = {};
  for (const a of apps) appNames[a.name.toLowerCase()] = true;

  const rows = [];
  const appRow = {};
  for (const a of apps) {
    const g = glyphOf ? glyphOf([a.id, a.exec, a.name]) : "";
    const r = { kind: "app", key: a.name, text: a.name, exec: a.exec, id: a.id, icon: a.icon, words: a.words || "",
      glyph: g || "", label: a.name, displayText: g ? g + "  " + a.name : a.name,
      sub: a.generic && a.generic.toLowerCase() !== a.name.toLowerCase() ? a.generic : "" };
    appRow[a.name.toLowerCase()] = r;
    rows.push(r);
  }
  for (const a of actions || []) {
    if (a.needs && !(states || {})[a.needs]) continue;
    const f = actionFace(a, states);
    // ONE ROW PER NAME (user, 2026-10-21: "two control hub entries"): the
    // shell writes .desktop files for its own windows, so an app and a verb
    // can share a name. The app stays and finds by the verb's words too.
    const twin = appRow[f.name.toLowerCase()];
    if (twin) { twin.words = (twin.words + " " + (a.keys || "")).trim(); continue; }
    rows.push({ kind: "shell", key: actionKey(a), text: f.name, exec: "", keys: a.keys, action: a,
      glyph: f.glyph, label: f.name, displayText: f.glyph + "  " + f.name });
  }
  for (const line of histLines) {
    const cmd = stripPrefix(line);
    if (appNames[cmd.toLowerCase()]) continue;
    const glyph = line.startsWith(ICON_P) ? ICON_P : ICON_T;
    rows.push({ kind: "hist", key: cmd, text: cmd, exec: "", glyph: splitGlyph(line).glyph || glyph,
      label: cmd, raw: line, displayText: line,
      sub: line.startsWith(ICON_P) ? "In the background" : "In the terminal" });
  }
  rows.sort((a, b) => {
    const fa = freq[a.key] || 0;
    const fb = freq[b.key] || 0;
    if (fa !== fb) return fb - fa;
    return a.key < b.key ? -1 : a.key > b.key ? 1 : 0;
  });
  return rows;
}

function filterRows(rows, query) {
  const q = (query || "").trim().toLowerCase();
  if (q === "") return rows.slice();
  const out = [];
  for (const r of rows) {
    // an app's generic name and keywords count, so "font" finds the font book
    const hay = (r.text + " " + (r.exec || "") + " " + (r.keys || "") + " " + (r.words || "")).toLowerCase();
    if (hay.includes(q)) out.push(r);
  }
  return out;
}

// ── THE ROOT LIST, IN SECTIONS ─────────────────────────────────────────────
// What the panel shows under its field: the rows that match, ranked, each
// with the `section` its heading comes from. Copies, so a row can be a
// suggestion and keep its place below without the two sharing a heading.

const SECTION_OF = { app: "Applications", shell: "Commands", hist: "History" };
// the panels that are the list itself rather than a row in it
const LISTED = { artemis: true, metis: true, lexi: true, folio: true, ideo: true, calypso: true };
const SUGGESTED = 5;

// How well a row answers the query: its name starting with it beats a word
// of it starting with it beats the letters anywhere. -1 is not at all.
function matchRank(r, q) {
  // your own word for it, or the start of it, is as good as its name
  if (r.alias && r.alias.startsWith(q)) return 0;
  const name = String(r.text || "").toLowerCase();
  if (name.startsWith(q)) return 0;
  if (name.indexOf(" " + q) >= 0 || name.indexOf("-" + q) >= 0) return 1;
  if (name.indexOf(q) >= 0) return 2;
  const hay = ((r.exec || "") + " " + (r.keys || "") + " " + (r.words || "") + " " + (r.sub || "")).toLowerCase();
  if ((" " + hay).indexOf(" " + q) >= 0) return 3;
  return hay.indexOf(q) >= 0 ? 4 : -1;
}

// `rows` already in frecency order (buildRows); a stable sort on the rank
// keeps that order among equals
function rankRows(rows, query) {
  const q = (query || "").trim().toLowerCase();
  if (q === "") return rows.slice();
  const scored = [];
  for (let i = 0; i < rows.length; ++i) {
    const k = matchRank(rows[i], q);
    if (k >= 0) scored.push({ r: rows[i], k, i });
  }
  scored.sort((a, b) => (a.k - b.k) || (a.i - b.i));
  return scored.map((x) => x.r);
}

function inSection(r, section) {
  return Object.assign({}, r, { section });
}

// "cb invoice" → the clipboard, searching for "invoice". The first word is a
// view's alias, or its god's name (the first of its keys: "folio", "lexi").
// Nothing after the word yet ("cb ") is the view itself, opened empty.
function scopedRow(actions, query) {
  const m = /^\s*(\S+)\s+(.*)$/.exec(String(query || ""));
  if (!m) return null;
  const word = m[1].toLowerCase();
  const rest = m[2].trim();
  for (const a of actions || []) {
    if (!a.view) continue;
    const god = String(a.keys || "").split(" ")[0];
    if (word !== a.alias && word !== god) continue;
    return { kind: "scoped", key: actionKey(a), view: a.view, rest, glyph: a.glyph, action: a,
      text: a.name, label: rest === "" ? a.name : a.say + " \u201C" + rest + "\u201D",
      sub: rest === "" ? "" : a.name, section: "Search in" };
  }
  return null;
}

// Whether the line is worth asking the calculator about at all. Metis'
// front end takes nearly anything for an expression ("firefox" is one until
// qalc says otherwise), so a run per keystroke of every app name would be a
// process for nothing: a digit in it, or a leading =.
function wantsCalc(query, prepKind) {
  const q = String(query || "").trim();
  if (q === "") return false;
  if (q.startsWith("=")) return q.length > 1;
  // a time somewhere, or how far between two places: Raycast's "time in syd"
  if (prepKind === "tz" || prepKind === "tzdiff" || prepKind === "geo") return true;
  // a conversion said in words: "usd to eur", "cups in ml" — a joining word
  // between two others; what qalc cannot read is not shown anyway
  if (prepKind === "qalc" && /^\S+(\s+\S+)*\s+(to|in|as|into)\s+\S+/i.test(q)) return true;
  // a date asked in words, "days until christmas", "next friday": two
  // words or more — "today" or "monday" alone is an app or a verb being
  // typed (clio's "Today's journal entry"), not a question
  if (prepKind === "local" && /\S\s+\S/.test(q)) return true;
  return (prepKind === "qalc" || prepKind === "local") && /\d/.test(q);
}

function calcQuestion(query) {
  return String(query || "").trim().replace(/^=\s*/, "");
}

// The Files section's rows, from artemis' paths: the name, and where it is
// (home as ~) under it. `glyphOf` is morpheus' glyphFor, handed in.
function fileRows(paths, home, glyphOf) {
  const out = [];
  for (const p of paths || []) {
    const isDir = p.charAt(p.length - 1) === "/";
    const shown = Artemis.shownPath(p, home);
    const cut = shown.lastIndexOf("/", shown.length - 2);
    const name = Artemis.basename(p) || shown;
    out.push({ kind: "file", key: p, path: p, isDir, text: name, label: name,
      sub: cut > 0 ? shown.slice(0, cut) : "",
      glyph: glyphOf ? glyphOf({ name, isDir }) : "" });
  }
  return out;
}

// The Clipboard and Snippets sections, from folio's own lists. `scoped` is
// a "cb …" line: every clip that matches (pictures too, while nothing is
// typed after the word); otherwise the few text clips and snippets that
// match the line, under the others. `stampOf(id)` is folio's "when";
// `thumbOf(id)` its picture, "" until it is made.
function clipRows(entries, imageIds, snippets, query, scoped, stampOf, thumbOf, perRow) {
  const q = String(query || "").trim();
  const out = [];
  if (!scoped && q.length < 2) return out;
  // the pictures as a grid: rows of `perRow` thumbnails ("pics"), a cell
  // chosen in the chosen row as an emoji is in its strip
  const per = Math.max(1, perRow || 4);
  const grid = (ids) => {
    for (let i = 0; i < ids.length; i += per)
      out.push({ kind: "pics", key: "pics:" + ids[i], section: "Pictures", text: "", label: "",
        cells: ids.slice(i, i + per).map((id) => ({ id, thumb: thumbOf ? thumbOf(id) : "",
          stamp: stampOf ? stampOf(id) : "" })) });
  };
  // "cb pictures" (or images): the pictures alone, all of them
  if (scoped && /^(pictures?|images?|pics?)$/i.test(q)) {
    grid((imageIds || []).slice(0, per * 10));
    return out;
  }
  // with nothing typed after "cb", the newest two rows of them above the
  // words
  if (scoped && q === "") grid((imageIds || []).slice(0, per * 2));
  for (const e of Folio.filterEntries(entries || [], q).slice(0, scoped ? 60 : 3)) {
    const line = String(e.preview || "").replace(/\s+/g, " ").trim();
    out.push({ kind: "clip", key: "clip:" + e.id, id: e.id, text: line, label: line,
      sub: stampOf ? stampOf(e.id) : "", glyph: "\uF0EA", section: "Clipboard" });
  }
  for (const sn of Folio.snippetRows(snippets || [], q).slice(0, scoped ? 40 : 3))
    out.push({ kind: "snip", key: "snip:" + sn.path, path: sn.path, content: sn.content,
      text: sn.preview, label: sn.preview, sub: sn.sub, glyph: "\uEB66", section: "Snippets" });
  return out;
}

// The Emoji (or Nerd glyphs) strips, from ideo's sets: `per` cells to a
// row. Any line of two letters or more gets one strip of what matches;
// "em …" / "nf …" (`scoped`) every match, a strip at a time, the whole set
// while nothing is typed after the word (capped: past that, type).
// `recent` (this set's list from parseGlyphs) leads: its own "Recently used"
// strips first, then the rest without them
function glyphRows(entries, query, nerd, scoped, per, recent) {
  const q = String(query || "").trim();
  if (!scoped && q.length < 2) return [];
  const n = Math.max(1, per || 14);
  const all = Ideo.filterEntries(entries || [], q);
  const order = {};
  (recent || []).forEach((c, i) => { order[c] = i; });
  const used = all.filter((e) => e.char in order).sort((a, b) => order[a.char] - order[b.char]);
  const rest = all.filter((e) => !(e.char in order)).slice(0, Math.max(0, (scoped ? n * 12 : n) - (scoped ? 0 : used.length)));
  const out = [];
  const strips = (list, section, tag) => {
    for (let i = 0; i < list.length; i += n)
      out.push({ kind: "glyphs", key: (nerd ? "nf:" : "em:") + tag + i, nerd: !!nerd, section,
        cells: list.slice(i, i + n).map((e) => ({ char: e.char, name: e.name || e.cls || "", cls: e.cls || "" })),
        text: "", label: "" });
  };
  strips(used.slice(0, scoped ? RECENT_GLYPHS : n), "Recently used", "r");
  strips(rest, nerd ? "Nerd glyphs" : "Emoji", "");
  return out;
}

// ── TOP RESULTS ──────────────────────────────────────────────────────────
// Raycast's: the best few of everything that has a name — apps, commands,
// files, the command lines in the history — ranked together. Only a name
// that STARTS with the line, or has a word that does, is good enough to be
// lifted out of its section (matchRank 0 or 1); among those the closer
// match first, then what is used most (cynosure's frecency, artemis' for a
// file), then apps before commands before files before history.
const TOP = 3;
const TOP_ORDER = { app: 0, shell: 1, file: 2, hist: 3 };
function topRows(ranked, files, query, freq, fileFreq) {
  const q = String(query || "").trim().toLowerCase();
  if (q === "") return [];
  const cands = [];
  for (const r of ranked || []) {
    const k = matchRank(r, q);
    if (k <= 1) cands.push({ r, k, use: (freq || {})[r.key] || 0 });
  }
  for (const f of files || []) {
    const k = matchRank({ text: f.label, alias: f.alias }, q);
    if (k >= 0 && k <= 1) cands.push({ r: f, k, use: (fileFreq || {})[f.path] || 0 });
  }
  // an alias typed whole is first of all
  for (const c of cands) if (c.r.alias === q) c.k = -1;
  cands.sort((a, b) => (a.k - b.k) || (b.use - a.use) || (TOP_ORDER[a.r.kind] - TOP_ORDER[b.r.kind]));
  return cands.slice(0, TOP).map((c) => c.r);
}

// ── YOUR SCRIPTS (2026-11-01) ──────────────────────────────────────────────
// Any script in ~/.config/zenworks/scripts is a command, Raycast's script
// commands: comment lines at its top say how it shows and runs —
//   # @title Restart Waybar      what the row says (else the file's name)
//   # @glyph                    its glyph
//   # @mode silent              silent · terminal · output (a notification)
//   # @argument a city          it takes words: typed after its @word
//   # @word wb                  the word (else the file's name, lowercased)
//   # @keywords bar panel       more words it is found by
// "#", "//" and "--" comments all count, so any language does.
function scriptsDir() {
  return Paths.configDir() + "/zenworks/scripts";
}
// each file, then the header lines of its first forty
function scriptsListCommand() {
  return "for f in \"$1\"/*; do [ -f \"$f\" ] || continue; printf '\\036%s\\n' \"$f\"; "
    + "head -n 40 -- \"$f\" | grep -E '^[[:space:]]*(#|//|--)[[:space:]]*@'; done";
}
function parseScripts(text) {
  const out = [];
  for (const rec of String(text || "").split("\u001e")) {
    const lines = rec.split("\n");
    const path = lines[0].trim();
    if (path === "") continue;
    const file = path.slice(path.lastIndexOf("/") + 1);
    const stem = file.replace(/\.[^.]+$/, "");
    const meta = {};
    for (const l of lines.slice(1)) {
      const m = /^\s*(?:#|\/\/|--)\s*@(\w+)\s*(.*)$/.exec(l);
      if (m && meta[m[1].toLowerCase()] === undefined) meta[m[1].toLowerCase()] = m[2].trim();
    }
    const nice = stem.replace(/[-_]+/g, " ").trim();
    const mode = /^(silent|terminal|output)$/.test(meta.mode || "") ? meta.mode : "silent";
    out.push({ path, title: meta.title || nice.charAt(0).toUpperCase() + nice.slice(1),
      glyph: meta.glyph || "\uF489", mode, argument: meta.argument || "",
      word: (meta.word || stem).toLowerCase().replace(/\s+/g, "-"), keywords: meta.keywords || "" });
  }
  return out;
}
// each script as a command: one that takes words types its word when
// chosen; one that does not runs (CynosurePopup.runInline)
function scriptActions(scripts) {
  return (scripts || []).map((sc) => sc.argument
    ? { name: sc.title, glyph: sc.glyph, keys: sc.word + " " + sc.keywords + " script", line: sc.word + " ", alias: sc.word }
    : { name: sc.title, glyph: sc.glyph, keys: sc.word + " " + sc.keywords + " script", inline: "script", script: sc });
}
// "wb cairo": the script whose word starts the line, with the words after
function scriptFor(scripts, query) {
  const m = /^\s*(\S+)\s+(.*)$/.exec(String(query || ""));
  if (!m) return null;
  const word = m[1].toLowerCase();
  const sc = (scripts || []).find((x) => x.argument && x.word === word);
  if (!sc) return null;
  const arg = m[2].trim();
  return { kind: "script", key: "script:" + sc.path, script: sc, arg, glyph: sc.glyph, text: sc.title,
    label: arg ? sc.title + " \u2014 \u201C" + arg + "\u201D" : sc.title,
    sub: arg ? "" : "Type " + sc.argument + " after \u201C" + sc.word + "\u201D", section: "Script" };
}
// a new one, its header filled in to be changed
function scriptTemplate() {
  return "#!/usr/bin/env bash\n"
    + "# @title My script\n"
    + "# @glyph \uF489\n"
    + "# @mode output\n"
    + "# @argument\n"
    + "# @word mine\n"
    + "# @keywords\n"
    + "#\n"
    + "# A Cynosure command. The lines above say how it shows: @mode is silent (in\n"
    + "# the background), terminal (in your terminal) or output (what it prints,\n"
    + "# as a notification). Give @argument a few words (\"a city\") and it takes\n"
    + "# what is typed after its @word, as $1.\n"
    + "\n"
    + "echo \"Hello from Cynosure${1:+, $1}\"\n";
}

// ── OPEN WINDOWS (2026-11-01) ──────────────────────────────────────────────
// The windows that are open, as rows to go to: [{ address, title, app,
// name, ws, focused }] from Hyprland's toplevels (CynosurePopup). Any line
// that matches a title or an app finds a few; "win …" is the windows alone
// (every one with nothing after it), the one you are in last.
function windowRows(wins, query, scoped, glyphOf) {
  const q = String(query || "").trim().toLowerCase();
  if (!scoped && q === "") return [];
  const out = [];
  for (const w of wins || []) {
    const title = String(w.title || "");
    const name = String(w.name || w.app || "");
    const hay = (title + " " + name).toLowerCase();
    if (q !== "" && hay.indexOf(q) < 0) continue;
    out.push({ kind: "window", key: "win:" + w.address, address: w.address, text: title || name,
      label: title || name, sub: name + (w.ws ? " \u00B7 workspace " + w.ws : ""), focused: !!w.focused,
      here: !!w.here,
      glyph: (glyphOf ? glyphOf([w.app, title]) : "") || "\u{F05C4}", section: "Windows" });
  }
  // where you already are is the last place to go
  out.sort((a, b) => (a.focused ? 1 : 0) - (b.focused ? 1 : 0));
  return out.slice(0, scoped ? 40 : 5);
}

// `extra`: { files: fileRows(…), filesOnly: the line is "f …", fileFreq:
// artemis' frecency for the Top results, clips:
// clipRows(…), clipsOnly: the line is "cb …" }. The calculator is not a
// row: it draws itself over the list (CynosurePopup).
function rootRows(rows, query, freq, actions, extra) {
  const q = (query || "").trim();
  const out = [];
  const ex = extra || {};
  if (q === "") {
    const used = rows.filter((r) => (freq || {})[r.key] > 0).slice(0, SUGGESTED);
    const taken = {};
    for (const r of used) { out.push(inSection(r, "Suggestions")); taken[r.kind + "\u0000" + r.key] = true; }
    for (const kind of ["app", "shell", "hist"])
      for (const r of rows)
        if (r.kind === kind && !taken[r.kind + "\u0000" + r.key]) out.push(inSection(r, SECTION_OF[kind]));
    return out;
  }
  // aliased files first, and not again among the finder's
  const af = ex.aliasFiles || [];
  const seen = {};
  for (const f of af) seen[f.path] = true;
  const files = af.concat((ex.files || []).filter((f) => !seen[f.path])).map((r) => inSection(r, "Files"));
  const clips = ex.clips || [];
  const glyphs = ex.glyphs || [];
  // "f …" is the finder and nothing else, "cb …" the clipboard; "calc …"
  // the calculator, which draws itself above an empty list
  if (ex.filesOnly) return files;
  if (ex.clipsOnly) return clips.slice();
  if (ex.glyphsOnly) return glyphs.slice();
  if (ex.windowsOnly) return (ex.windows || []).slice();
  if (ex.settingsOnly) return (ex.settings || []).slice();
  if (ex.storeOnly) return (ex.store || []).slice();
  if (ex.packagesOnly) return (ex.packages || []).slice();
  if (ex.eventOnly) return ex.event ? [ex.event] : [];
  if (ex.notesOnly) return (ex.newNote ? [ex.newNote] : []).concat(ex.notes || []);
  const scoped = scopedRow(actions, query);
  if (scoped && LISTED[String(scoped.view).split(":")[0]]) return [];
  // a command with its argument ("volume 30"), said as what it will do
  if (ex.command) out.push(ex.command);
  if (scoped) out.push(scoped);
  // a quick link's word: the search, first; a script's, the same
  const link = scoped ? null : linkFor(ex.links, query);
  if (link) out.push(link);
  const script = scoped || link ? null : scriptFor(ex.scripts, query);
  if (script) out.push(script);
  const ranked = rankRows(rows, q);
  // the best few of everything named, first; each is then left out of its
  // own section below
  const top = topRows(ranked, files, q, freq, ex.fileFreq);
  const taken = {};
  for (const t of top) { out.push(inSection(t, "Top results")); taken[t.kind + "\u0000" + t.key] = true; }
  const free = (r) => !taken[r.kind + "\u0000" + r.key];
  for (const kind of ["app", "shell"])
    for (const r of ranked)
      if (r.kind === kind && free(r)) out.push(inSection(r, SECTION_OF[kind]));
  for (const w of ex.windows || []) out.push(w);
  for (const st of ex.settings || []) out.push(st);
  for (const nt of ex.notes || []) out.push(nt);
  for (const f of files) if (free(f)) out.push(f);
  for (const c of clips) out.push(c);
  for (const g of glyphs) out.push(g);
  for (const r of ranked)
    if (r.kind === "hist" && free(r)) out.push(inSection(r, SECTION_OF.hist));
  if (!scoped) {
    const quoted = "\u201C" + q + "\u201D";
    // Raycast's fallbacks: the line handed to each panel that can take it,
    // then run as a command
    const use = "Use " + quoted + " with\u2026";
    const fb = (name, glyph, word, sub) => out.push({ kind: "fallback", key: "fb:" + word, text: q,
      glyph, label: name, sub, action: { line: word + " " + q }, section: use });
    const web = (ex.links || []).find((l) => l.word === "web");
    if (web && !link) out.push(Object.assign(linkRow(web, q, use), { label: "Search the web", sub: "" }));
    fb("Search files", "\uF002", "f", "Artemis");
    fb("Search the clipboard", "\uF0EA", "cb", "Folio");
    fb("Search settings", "\uF013", "settings", "Oracle");
    fb("Search the store", "\uF07A", "store", "Ceres");
    if (/^\S+$/.test(q)) fb("Search packages", "\uF187", "pkg", "Ceres");
    fb("Search notes", NOTE_GLYPH, "notes", "Clio");
    fb("New note", NOTE_GLYPH, "note", "Clio");
    fb("New event", "\uF073", "event", "Chronos");
    if (/^\S+$/.test(q)) fb("Define", "\uF02D", "def", "Lexi");
    fb("Translate", "\uF1AB", "tr", "Lexi");
    fb("Find emoji", "\uF118", "em", "Ideo");
    out.push({ kind: "run", key: "run:t", mode: "Terminal", text: q, glyph: ICON_T,
      label: "Run " + quoted + " in the terminal", section: use });
    out.push({ kind: "run", key: "run:p", mode: "Process", text: q, glyph: ICON_P,
      label: "Run " + quoted + " in the background", section: use });
  }
  return out;
}

// ── THE ACTIONS PANEL (shift return) ────────────────────────────────────────────
// What a row can do besides return, Raycast's ⌘K: the first is always what
// return does, the rest each once. `hint` names a key that does it from the
// list too, where there is one. The calculator's card asks as { kind: "calc" }.
const A_COPY = "\uF0C5", A_OPEN = "\uF08E", A_FORGET = "\uF1F8", A_RUN = "\uF04B";
function hotkeyActs(r, a) {
  return r.hotkey ? [a("setHotkey", "Change hotkey\u2026", "\uF11C", r.hotkey), a("dropHotkey", "Remove hotkey", "\uF11C")]
    : [a("setHotkey", "Set hotkey\u2026", "\uF11C")];
}
function aliasActs(r, a) {
  return r.alias ? [a("setAlias", "Change alias \u201C" + r.alias + "\u201D\u2026", "\uF02B"), a("dropAlias", "Remove alias", "\uF02B")]
    : [a("setAlias", "Set alias\u2026", "\uF02B")];
}
function rowActions(r) {
  if (!r) return [];
  const a = (id, text, icon, hint) => ({ id, text, icon, hint: hint || "" });
  switch (r.kind) {
  case "app":
    return [a("go", "Open", A_OPEN, "return"), ...aliasActs(r, a), ...hotkeyActs(r, a), a("copyName", "Copy name", A_COPY),
      a("forget", "Forget how often it is used", A_FORGET)];
  case "shell":
    return [a("go", r.action && r.action.view ? "Open" : "Run", A_RUN, "return"), ...aliasActs(r, a), ...hotkeyActs(r, a),
      a("copyName", "Copy name", A_COPY), a("forget", "Forget how often it is used", A_FORGET)];
  case "hist":
    return [a("go", "Run", A_RUN, "return"), a("runTerminal", "Run in the terminal", "\uEA85"),
      a("runProcess", "Run in the background", "\uEB7F"), ...hotkeyActs(r, a), a("copyName", "Copy command", A_COPY),
      a("forget", "Remove from history", A_FORGET, "delete")];
  case "file":
    return [a("go", r.isDir ? "Open in Terminus" : "Open", A_OPEN, "return"),
      a("reveal", "Show in Terminus", "\uF07C"),
      ...(r.isDir ? [] : [a("openWith", "Open with\u2026", "\uF14C")]),
      ...(r.isDir ? [] : [a("copyFile", "Copy the file", A_COPY)]),
      a("copyPath", "Copy path", A_COPY), a("copyName", "Copy name", A_COPY), ...aliasActs(r, a), ...hotkeyActs(r, a)];
  case "clip":
    return [a("go", "Copy", A_COPY, "return"),
      ...(/^https?:\/\/\S+$/i.test(String(r.label || "").trim()) ? [a("openUrl", "Open link", A_OPEN)] : []),
      a("keep", "Keep as snippet", "\uEB66", "ctrl s"),
      a("drop", "Remove from the clipboard", A_FORGET, "delete")];
  case "clipimg": case "pics":
    return [a("go", "Copy", A_COPY, "return"), a("markUp", "Annotate", "\uF040"),
      a("viewPic", "Open in Picasso", "\uF03E"), a("savePic", "Save to Pictures", "\uF0C7"),
      a("drop", "Remove from the clipboard", A_FORGET, "delete")];
  case "snip":
    return [a("go", "Copy", A_COPY, "return"), a("pasteSnip", "Paste", "\uF0EA"), a("edit", "Edit", "\uF040", "ctrl e"),
      a("newSnippet", "New snippet", "\uEB66", "ctrl n"), a("drop", "Move to the trash", A_FORGET, "delete")];
  case "glyphs":
    // the three formats Ideo's own strip offered (glyph, class, codepoint)
    return r.nerd
      ? [a("go", "Copy glyph", A_COPY, "return"), a("copyName", "Copy class name", A_COPY),
        a("copyCode", "Copy codepoint", A_COPY)]
      : [a("go", "Paste", "\uF0EA", "return"), a("copyGlyph", "Copy", A_COPY),
        a("copyName", "Copy its name", A_COPY), a("copyCode", "Copy codepoint", A_COPY)];
  case "calc":
    return [a("go", "Paste answer", "\uF0EA", "return"), a("copyAnswer", "Copy answer", A_COPY, "ctrl return"),
      a("copyQuestion", "Copy question", A_COPY), a("tape", "Open the tape", "\uF1DA", "ctrl h"),
      a("explain", "Explain the working", "\uF05A", "ctrl e")];
  case "lexi":
    return [a("go", "Copy", A_COPY, "return"),
      ...(r.say ? [a("lexiSay", r.mode === "dict" ? "Say the word" : "Read it out", "\uF028", "alt p")] : []),
      ...(r.mode === "dict" && r.more ? [a("lexiMore", "Show more or fewer senses", "\uF036", "alt e")] : []),
      ...(r.swap ? [a("lexiSwap", "Swap the languages", "\uF0EC", "alt s")] : [])];
  case "storeapp":
    return [a("go", "Open in Ceres", A_OPEN, "return"),
      ...(!r.installed && r.pkg && r.source !== "flatpak" ? [a("storeInstall", "Install", "\uF019")] : []),
      a("copyName", "Copy name", A_COPY)];
  case "package":
    return [a("go", r.installed ? "Remove\u2026" : "Install\u2026", r.installed ? A_FORGET : "\uF019", "return"),
      a("pkgShow", "Show in Ceres", A_OPEN), a("copyName", "Copy name", A_COPY)];
  case "newevent":
    return r.bad ? [] : [a("go", "Add to the calendar", "\uF073", "return"), a("eventOpen", "Add and open the calendar", A_OPEN)];
  case "note":
    return [a("go", "Open in Clio", A_OPEN, "return"), a("copyName", "Copy title", A_COPY)];
  case "newnote":
    return [a("go", "Save the note", "\uE678", "return"), a("noteOpen", "Save and open in Clio", A_OPEN)];
  case "setting":
    return [a("go", "Open in Oracle", A_OPEN, "return"), a("copyName", "Copy name", A_COPY)];
  case "answer":
    return [a("go", "Copy", A_COPY, "return"),
      ...(r.weather ? [a("forecast", "Open the forecast", "\uF073")] : []),
      ...(r.calDay ? [a("calOpen", "Open the calendar", "\uF073")] : [])];
  case "script":
    return [a("go", "Run", A_RUN, "return"), ...hotkeyActs(r, a), a("editScript", "Edit the script", "\uF040"),
      a("copyPath", "Copy its path", A_COPY)];
  case "window":
    return [a("go", "Go to it", A_OPEN, "return"),
      ...(r.here ? [] : [a("winHere", "Move to this workspace", "\uF2D2")]),
      a("winFloat", "Float or tile", "\uF2D0"), a("winCenter", "Center", "\uF0B2"),
      a("winFull", "Fullscreen", "\uF065"), a("closeWin", "Close the window", A_FORGET),
      a("copyName", "Copy title", A_COPY)];
  case "argcmd":
    return [a("go", "Do it", A_RUN, "return")];
  case "link":
    return [a("go", "Open in the browser", A_OPEN, "return"), ...hotkeyActs(r, a), a("copyUrl", "Copy address", A_COPY),
      ...(r.own ? [a("dropLink", "Remove quick link", A_FORGET)] : [])];
  case "run": case "fallback": case "scoped":
    return [a("go", r.kind === "run" ? "Run" : "Use", A_RUN, "return")];
  }
  return [];
}

// "U+F0C5", or "U+1F44D U+1F3FD" for an emoji made of several (walked by
// code point: V4's Array.from splits surrogate pairs)
function codepoints(ch) {
  const s = String(ch || ""), out = [];
  for (let i = 0; i < s.length; i++) {
    const c = s.codePointAt(i);
    if (c > 0xFFFF) i++;
    if (c === 0xFE0F || c === 0x200D) continue;
    out.push("U+" + c.toString(16).toUpperCase().padStart(4, "0"));
  }
  return out.join(" ");
}

// What return does to the row, for the hint strip
function verbOf(r) {
  if (!r) return "";
  if (r.kind === "app") return "open";
  if (r.kind === "file") return r.isDir ? "open in terminus" : "open";
  if (r.kind === "setting") return "open in oracle";
  if (r.kind === "note") return "open in clio";
  if (r.kind === "package") return r.installed ? "remove" : "install";
  if (r.kind === "newnote") return "save";
  if (r.kind === "newevent") return r.bad ? "" : "add to calendar";
  if (r.kind === "storeapp") return "open in ceres";
  if (r.kind === "fallback") return "use";
  if (r.kind === "link") return "open";
  if (r.kind === "argcmd") return "do it";
  if (r.kind === "window") return "go to it";
  if (r.kind === "script") return "run";
  if (r.kind === "clip" || r.kind === "clipimg" || r.kind === "pics" || r.kind === "snip") return "copy";
  if (r.kind === "glyphs") return r.nerd ? "copy" : "paste";
  if (r.kind === "scoped") return r.rest === "" ? "open" : "search";
  if (r.kind === "shell") return r.action && r.action.view ? "open" : "run";
  return "run";
}

function kindName(r) {
  if (!r) return "";
  if (r.kind === "file") return r.isDir ? "Directory" : "File";
  if (r.kind === "fallback") return "Command";
  if (r.kind === "link") return "Quick link";
  if (r.kind === "argcmd") return "Command";
  if (r.kind === "window") return r.focused ? "This window" : "Window";
  if (r.kind === "script") return "Script";
  if (r.kind === "setting") return "Setting";
  if (r.kind === "note") return r.entry ? "Journal entry" : "Note";
  if (r.kind === "package") return r.installed ? "Installed" : r.aur ? "AUR package" : "Package";
  if (r.kind === "newnote") return "Command";
  if (r.kind === "newevent") return r.bad ? "" : "New event";
  if (r.kind === "storeapp") return r.installed ? "Installed" : "App";
  if (r.kind === "clip" || r.kind === "clipimg" || r.kind === "pics") return "Clip";
  if (r.kind === "snip") return "Snippet";
  if (r.kind === "glyphs") return r.nerd ? "Nerd glyph" : "Emoji";
  return { app: "Application", shell: "Command", hist: "Command line",
    scoped: "Quick panel", run: "Command line" }[r.kind] || "";
}

function addHistory(lines, cmd, mode, customIcon) {
  const icon = customIcon || (mode === "Terminal" ? ICON_T : ICON_P);
  const formatted = icon + "  " + cmd;
  const filtered = lines.filter((e) => e !== formatted);
  filtered.unshift(formatted);
  return filtered.slice(0, HIST_MAX);
}

function deleteHistoryLine(lines, rawLine) {
  return lines.filter((e) => e !== rawLine);
}

function bumpFreq(map, key) {
  if (!key) return map;
  map[key] = (map[key] || 0) + 1;
  return map;
}

function serializeHistory(lines) {
  return lines.length ? lines.join("\n") + "\n" : "";
}

function serializeFreq(map) {
  const parts = [];
  for (const k in map) parts.push(k + "=" + map[k]);
  return parts.length ? parts.join("\n") + "\n" : "";
}

// `term` is oracle's Default apps terminal. Empty is the old guess below.
function terminalCommand(cmd, term) {
  const t = String(cmd).trim().toLowerCase();
  if (t === "kitty") {
    return "setsid kitty --detach " + Strings.shellQuote(cmd) + " >/dev/null 2>&1 &";
  }
  // footclient BY NAME when it is there, and the reason is the window rule.
  //
  // xdg-terminal-exec only forwards --hold and --title if the terminal's
  // desktop entry declares TerminalArgHold= and TerminalArgTitle=. foot.desktop
  // declares neither, so the script dropped both without a word: every command
  // that printed and exited took its window with it, and the window that did
  // survive was class `foot` with no title — while the hyprland rule is written
  // for `footclient` + title `cynosure` and so never matched.
  //
  // Calling footclient directly gets all three right at once: the server is
  // already up from hyprland's autostart, --hold is foot's own flag, and the
  // class is what the rule expects. xdg-terminal-exec stays the fallback for a
  // machine with no foot on it, where the rule does not apply anyway.
  const run = shell() + " -i -c " + Strings.shellQuote(cmd);
  // ── THE TERMINAL YOU CHOSE ─────────────────────────────────────────
  // Oracle puts its entry first in xdg-terminals.list, so xdg-terminal-exec
  // already lands in it; the title and the hold go through the entry's own
  // TerminalArg keys, which kitty, alacritty and ghostty declare. foot is
  // the one that does not, so it is still called by name, for the reason
  // above.
  const want = String(term || "").trim().split(/\s+/)[0].replace(/.*\//, "");
  if (want === "foot" || want === "footclient") {
    return "if command -v footclient >/dev/null 2>&1; then "
      + "footclient --hold --title=cynosure " + run + "; "
      + "else foot --hold --title=cynosure " + run + "; fi"
      + " >/dev/null 2>&1 &";
  }
  if (want !== "")
    return "xdg-terminal-exec --title=cynosure --hold -e " + run + " >/dev/null 2>&1 &";
  return "if command -v footclient >/dev/null 2>&1; then "
    + "footclient --hold --title=cynosure " + run + "; "
    + "else xdg-terminal-exec --title=cynosure --hold -e " + run + "; fi"
    + " >/dev/null 2>&1 &";
}

function processCommand(cmd) {
  return "setsid " + shell() + " -i -c " + Strings.shellQuote(cmd) + " >/dev/null 2>&1 &";
}

// gio launch, by way of Desktop — NOT gtk-launch.
//
// gtk-launch runs the entry's Exec line and nothing else, so an entry that
// declares Terminal=true was started with no terminal around it and died
// immediately with no error anywhere. See morpheus/Desktop.qml, which also
// owns the search path all three launching layers now share.
function launchAppCommand(id) {
  return Desktop.launchCommand(id, "");
}

// the shell's one escaping rule (morpheus/Strings)
function escMarkup(s) {
  return Strings.escapeHtml(s);
}

function highlight(text, query) {
  const t = String(text);
  const q = (query || "").trim();
  if (q === "") return escMarkup(t);
  const idx = t.toLowerCase().indexOf(q.toLowerCase());
  if (idx < 0) return escMarkup(t);
  return escMarkup(t.slice(0, idx)) + "<u>" + escMarkup(t.slice(idx, idx + q.length)) +
      "</u>" + escMarkup(t.slice(idx + q.length));
}
