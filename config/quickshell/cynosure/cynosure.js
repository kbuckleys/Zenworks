// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

.pragma library
.import qs.morpheus as Morpheus
.import Quickshell as QuickshellModule
.import "../artemis/artemis.js" as Artemis
.import "folio/folio.js" as Folio
.import "ideo/ideo.js" as Ideo
.import "lexi/lexi.js" as Lexicon
.import "../ceres/store.js" as Store
.import "../clio/notes.js" as Notes
.import "../chronos/chronos.js" as Chr
.import "answers.js" as Answers
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

// ── WHAT YOU PICK FOR WHAT YOU TYPE (2026-11-04, Raycast's) ───────────────
// "br" and then Brave: next time "br" has Brave first, whatever else fits
// it better. Kept per line typed and per start of it from two letters ("bra"
// teaches "br" too, the whole line twice as much); the newest PICKS_MAX lines
// are kept. { line: { key: count } }
const PICKS_MAX = 400;
function picksPath() {
  return Paths.cacheDir() + "/cynosure-picks.json";
}
// a plain { } of its own, as the aliases file is
function parsePicks(text) { return parseAliases(text); }
function serializePicks(picks) { return JSON.stringify(picks || {}) + "\n"; }
function notePick(picks, query, key) {
  const q = String(query || "").trim().toLowerCase();
  const out = Object.assign({}, picks || {});
  if (!key || q === "" || q.length > 40) return out;
  for (let n = Math.min(2, q.length); n <= q.length; n++) {
    const line = q.slice(0, n);
    const was = Object.assign({}, out[line] || {});
    was[key] = (was[key] || 0) + (n === q.length ? 2 : 1);
    // touched lines move to the end, so the oldest are the first dropped
    delete out[line];
    out[line] = was;
  }
  const lines = Object.keys(out);
  for (let i = 0; i < lines.length - PICKS_MAX; i++) delete out[lines[i]];
  return out;
}
function pickCount(picks, query, key) {
  const m = picks && picks[String(query || "").trim().toLowerCase()];
  return m && m[key] || 0;
}

// ── WHAT YOU SEARCHED (2026-11-01) ─────────────────────────────────────────
// The lines that led somewhere, newest first: "history" lists them, and a
// chip with nothing after it leads with its own. Kept in the cache with the
// frecency.
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
  const key = queryText(t);
  return [t].concat((list || []).filter((x) => queryText(x) !== key)).slice(0, QUERIES_MAX);
}
// ── WHAT WAS SEARCHED, NOT WHAT WAS TYPED (user, 2026-11-07) ──────────────
// A history entry is the line that reaches what you picked, and the chip it
// was searched under: "line<TAB>glyph<TAB>chip". Typed "cla", picked Claude:
// "Claude", under App; picked Nord under the theme chip: "theme Nord". A
// line written before this has no chip part and still reads.
function queryText(entry) { return String(entry || "").split("\t")[0]; }
function queryTag(entry) {
  const p = String(entry || "").split("\t");
  return p.length >= 3 && p[2] !== "" ? { glyph: p[1], text: p[2] } : null;
}
function queryEntry(line, tag) {
  const flat = (s) => String(s || "").replace(/[\t\n\r]+/g, " ").trim();
  const l = flat(line);
  return l !== "" && tag && flat(tag.text) !== "" ? l + "\t" + flat(tag.glyph) + "\t" + flat(tag.text) : l;
}
// a name without the marks a list puts beside it (a light theme's glyph)
function plainName(s) {
  return String(s || "").replace(/[\uE000-\uF8FF]|[\u{F0000}-\u{10FFFD}]/gu, "").replace(/\s+/g, " ").trim();
}
// The rows whose name is what was searched for: their whole name stands in
// for the start that was typed. Everything else (a clip, a sum, a word
// looked up) keeps the line as typed, and a clip's text is never kept.
const PICK_NAMED = ["app", "window", "file", "link", "contact", "script", "traymenu"];
function pickedLine(query, chipWord, row) {
  const q = String(query || "").trim();
  if (!row) return q;
  const named = PICK_NAMED.indexOf(row.kind) >= 0 || (row.kind === "argcmd" && !!row.cmd && row.cmd.kind === "theme");
  const name = named ? plainName(row.label || row.text) : "";
  return name === "" ? q : (chipWord ? chipWord + " " : "") + name;
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
  // the bare form takes a language's NAME, not a code: "check in hi" and
  // "files in it" were translations to Hindi and Italian (audit 11-09);
  // "tr … in es" still takes codes
  if ((m = /^(?:what(?:'?s| is) )?(.+?) in (\S+(?: \S+)?)$/i.exec(q)) && !/^[a-z]{2,3}(-[a-z]{2,4})?$/i.test(m[2])
      && Lexicon.langFor(m[2]) && words(m[1]) <= LEXI_WORDS && !/\d/.test(m[1]))
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
// the ones whose NAME starts with a word of it (the list keeps three, and
// a row for the rest), so a search for an app is not buried; "settings …"
// lists every match.
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
  return out.slice(0, 60);
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
  return hits.slice(0, 40).map((h) => {
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

// ── TASKS AND REMINDERS (2026-11-02) ──────────────────────────────────────
// "todo pay rent friday", "remind me in 20 min to call mom": a checklist
// item in Clio's "Tasks" note, its time the item's reminder (Clio tells it
// when it is due, window open or not). The when comes out of the words —
// "in 20 min", "in an hour" here, a day and a clock by Chronos' own
// reading (chronos.js parseNatural) — and the rest is the task.
//   → { title, due } (due 0: no time), or { error }
const REL_UNIT = { h: 3600000, hr: 3600000, hrs: 3600000, hour: 3600000, hours: 3600000,
  m: 60000, min: 60000, mins: 60000, minute: 60000, minutes: 60000 };
function taskWhen(words, now) {
  const at = now || new Date();
  let s = " " + String(words || "").trim() + " ";
  let due = 0;
  const rel = /\s(?:in|after)\s+(half an?|an?|\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)(?=\s)/i.exec(s);
  if (rel) {
    const n = /^half/i.test(rel[1]) ? 0.5 : /^an?$/i.test(rel[1]) ? 1 : Number(rel[1]);
    due = at.getTime() + Math.round(n * REL_UNIT[rel[2].toLowerCase()]);
    s = s.slice(0, rel.index) + " " + s.slice(rel.index + rel[0].length);
  }
  let title = s.trim();
  if (!rel && title !== "") {
    const q = Chr.parseNatural(title, Chr.isoOf(at), at);
    // "tomorrow at 9" and nothing else: Chronos says so
    if (q.error) return { error: q.error };
    // what Chronos took out of the words was a day or a clock
    const said = q.title.replace(/\s+/g, "") !== title.replace(/\s+/g, "").replace(/@/g, "");
    if (!q.allDay) {
      const m = /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d)$/.exec(q.start);
      due = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]).getTime();
      // a clock alone that has gone by today is tomorrow's
      if (due <= at.getTime() && q.iso === Chr.isoOf(at) && !/\btoday\b/i.test(title)) due += 86400000;
    } else if (said) {
      const d = Chr.dateOf(q.iso);
      due = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 9, 0).getTime();
      // today, with nine o'clock gone: no time rather than one already past
      if (due <= at.getTime()) due = 0;
    }
    title = q.title + (q.location ? " @ " + q.location : "");
  }
  title = title.replace(/^(to|that)\s+/i, "").replace(/\s+(at|on|by)$/i, "").trim();
  if (title === "") return { error: "Say what it is, not only when" };
  return { title: title.charAt(0).toUpperCase() + title.slice(1), due };
}
// a due time said in a row: "Today 14:00", "Tomorrow 09:00", "Thu 18:00"
function dueWords(due, now) {
  const t = Notes.dueText(due, (now || new Date()).getTime());
  return /^\d/.test(t) && t.length <= 5 ? "Today " + t : t;
}
const TASK_GLYPH = "\uF14A", REMIND_GLYPH = "\u{F009F}";
// "todo …" / "remind me …": the row that adds it, as it will be kept
function newTaskRow(words, remind, now) {
  const w = String(words || "").trim();
  if (w === "") return null;
  const t = taskWhen(w, now);
  const glyph = remind ? REMIND_GLYPH : TASK_GLYPH;
  if (t.error) return { kind: "newtask", key: "newtask", text: w, label: t.error, sub: "", bad: true, glyph, section: "" };
  if (remind && !t.due) return { kind: "newtask", key: "newtask", text: w, bad: true, glyph, section: "",
    label: "Say when: in 20 min, at 5pm, tomorrow 9am", sub: "" };
  const shown = t.title.length > 60 ? t.title.slice(0, 59) + "\u2026" : t.title;
  return { kind: "newtask", key: "newtask", text: w, title: t.title, due: t.due, remind: !!remind, glyph, section: "",
    label: (remind ? "Remind me to \u201C" : "New task \u201C") + shown + "\u201D",
    sub: (t.due ? dueWords(t.due, now) + " \u00B7 " : "") + "Clio" };
}
// "todos …" / "tasks …": every open checklist item (notes.js tasks), under
// Clio's own groups (Overdue, Today, This week, Later, No date)
function taskRows(notes, query, now) {
  const q = String(query || "").trim().toLowerCase();
  const at = now || new Date();
  const label = {};
  for (const g of Notes.TASK_GROUPS) label[g.id] = g.label;
  return Notes.tasks(notes || [], at.getTime())
    .filter((t) => q === "" || (t.h + " " + t.title).toLowerCase().indexOf(q) >= 0)
    .slice(0, 60)
    .map((t) => ({ kind: "task", key: "task:" + t.id + ":" + t.at + ":" + t.h, task: t, text: t.h, label: t.h,
      sub: (t.due ? dueWords(t.due, at) + " \u00B7 " : "") + t.title, glyph: "\uF096",
      section: label[t.group] || "Tasks" }));
}

// ── BOOKS (2026-11-02) ────────────────────────────────────────────────────
// "book …": Minerva's library (minerva.json, cleaned by minerva.js), the
// last read first; return opens it where it was left
const BOOK_GLYPH = { pdf: "\uF1C1", epub: "\u{F03D2}", comic: "\u{F02F9}", text: "\uF15C" };
function bookRows(books, query) {
  const q = String(query || "").trim().toLowerCase();
  return (books || []).filter((b) => q === "" || (b.title + " " + b.author).toLowerCase().indexOf(q) >= 0)
    .slice().sort((a, b) => (b.opened || 0) - (a.opened || 0) || (b.added || 0) - (a.added || 0))
    .slice(0, 40)
    .map((b) => ({ kind: "book", key: "book:" + b.path, path: b.path, book: b, text: b.title, label: b.title,
      sub: [b.author, b.finished > 0 ? "Finished" : b.opened > 0 ? Math.round(b.progress * 100) + "%" : "Unread"]
        .filter((x) => x).join(" \u00B7 "),
      glyph: BOOK_GLYPH[b.kind] || BOOK_GLYPH.epub, section: "Books" }));
}

// ── SOUND OUTPUT (2026-11-02) ─────────────────────────────────────────────
// "output …": the devices sound can go to ({ id, label }, Pipewire's sinks);
// return makes it the one in use
function outputRows(sinks, inUse, query) {
  const q = String(query || "").trim().toLowerCase();
  return (sinks || []).filter((s) => q === "" || s.label.toLowerCase().indexOf(q) >= 0)
    .map((s) => ({ kind: "output", key: "out:" + s.name, id: s.id, name: s.name, text: s.label, label: s.label,
      sub: s.id === inUse ? "In use" : "", glyph: s.id === inUse ? "\u{F057E}" : "\u{F04C3}", section: "Sound output" }));
}

// ── COLORS YOU PICKED (2026-11-02) ────────────────────────────────────────
// "colors …": Picasso's picker palette (picker-palette.json, newest first),
// each its own swatch; return copies the hex
function colorRows(palette, query) {
  const q = String(query || "").trim().toLowerCase().replace(/^#/, "");
  return (palette || []).filter((h) => q === "" || h.slice(1).indexOf(q) >= 0)
    .map((h) => {
      const forms = Answers.colorForms(h);
      return { kind: "pcolor", key: "pc:" + h, hex: h, text: h.toUpperCase(), label: h.toUpperCase(),
        sub: forms[1][1] + " \u00B7 " + forms[2][1], forms, ink: h, glyph: "\u{F0765}", section: "Colors you picked" };
    });
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
// every control character as \ddd, as morpheus/hypr.js lua(): a raw \r
// (a pasted label) ended the line Lua was reading
function luaQuote(s) {
  return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, " ")
    .replace(/[\u0000-\u001f\u007f]/g, (c) => "\\" + ("00" + c.charCodeAt(0)).slice(-3)) + "\"";
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

// ── PLACES (2026-11-02) ───────────────────────────────────────────────────
// "go …": terminus' bookmarks (terminus-bookmarks, a path a line), its
// network places (terminus-network.json + what gvfs has mounted, network.js
// rows) and the directories artemis has opened most; return opens Terminus
// there, a network place not mounted yet connects first (Terminus place).
// `glyphOf` (morpheus' glyphFor, handed in): a directory wears its glyph
// from the map, as Terminus shows it (2026-11-05)
function placeRows(bookmarks, places, dirs, query, home, glyphOf) {
  const q = String(query || "").trim().toLowerCase();
  const hit = (name, path) => q === "" || (name + " " + path).toLowerCase().indexOf(q) >= 0;
  const out = [];
  const seen = {};
  const dirRow = (p, section, glyph) => {
    const path = String(p).replace(/(.)\/+$/, "$1");
    if (seen[path]) return;
    const shown = Artemis.shownPath(path, home);
    const name = path === "/" ? "/" : shown.slice(shown.lastIndexOf("/") + 1) || shown;
    if (!hit(name, shown)) return;
    seen[path] = true;
    out.push({ kind: "place", key: "place:" + path, path, uri: "", text: name, label: name,
      sub: shown, glyph: (glyphOf ? glyphOf({ name, isDir: true, path }) : "") || glyph, section });
  };
  for (const b of bookmarks || []) dirRow(b, "Bookmarks", "");
  for (const p of places || []) {
    const name = p.name || String(p.uri).replace(/^\w+:\/\//, "");
    if (!hit(name, p.uri)) continue;
    out.push({ kind: "place", key: "net:" + p.uri, path: p.path || "", uri: p.uri, text: name, label: name,
      sub: p.uri + (p.path ? "" : " · not connected"), glyph: "\u{F0870}", section: "Network" });
  }
  for (const d of dirs || []) dirRow(d, "Often visited", "");
  return out.slice(0, 60);
}

// ── WINDOW PLACES (2026-11-02) ────────────────────────────────────────────
// Where "left half", "maximize", "1280x720" put a window: the monitor
// (Hyprland's own numbers: x, y, width, height in pixels, scale, transform,
// reserved [left, top, right, bottom]) less its bars and the outer gaps,
// in layout coordinates. `size` { w, h } is centered.
function snapRect(mon, gaps, where, size) {
  const turned = (Number(mon.transform) || 0) % 2 === 1;
  const sc = Number(mon.scale) || 1;
  const W = (turned ? mon.height : mon.width) / sc, H = (turned ? mon.width : mon.height) / sc;
  const r = (mon.reserved || [0, 0, 0, 0]).map((v) => Number(v) || 0);
  const g = Number(gaps) || 0;
  const ax = mon.x + r[0] + g, ay = mon.y + r[1] + g;
  const aw = W - r[0] - r[2] - 2 * g, ah = H - r[1] - r[3] - 2 * g;
  const half = Math.round(g / 2);
  const R = (x, y, w, h) => ({ x: Math.round(x), y: Math.round(y), w: Math.round(w), h: Math.round(h) });
  // thirds and quarters (2026-11-03): a third is a third of the width less
  // its share of the gaps between; two thirds take the gap in between too
  const third = (aw - 2 * g) / 3;
  const qw = aw / 2 - half, qh = ah / 2 - half;
  switch (where) {
  case "left3": return R(ax, ay, third, ah);
  case "center3": return R(ax + third + g, ay, third, ah);
  case "right3": return R(ax + 2 * (third + g), ay, third, ah);
  case "left23": return R(ax, ay, 2 * third + g, ah);
  case "right23": return R(ax + third + g, ay, 2 * third + g, ah);
  case "tl": return R(ax, ay, qw, qh);
  case "tr": return R(ax + aw / 2 + half, ay, qw, qh);
  case "bl": return R(ax, ay + ah / 2 + half, qw, qh);
  case "br": return R(ax + aw / 2 + half, ay + ah / 2 + half, qw, qh);
  case "centerHalf": return R(ax + aw / 4, ay, aw / 2, ah);
  case "almost": return R(ax + aw * 0.05, ay + ah * 0.05, aw * 0.9, ah * 0.9);
  // the window's own place (`size` { x, y, w, h }): a tenth larger or
  // smaller about its middle, or as wide / as tall as there is room
  case "grow": case "shrink": {
    const f = where === "grow" ? 1.1 : 1 / 1.1;
    const w = Math.min(aw, size.w * f), h = Math.min(ah, size.h * f);
    const x = Math.max(ax, Math.min(ax + aw - w, size.x + (size.w - w) / 2));
    const y = Math.max(ay, Math.min(ay + ah - h, size.y + (size.h - h) / 2));
    return R(x, y, w, h);
  }
  case "maxW": return R(ax, Math.max(ay, size.y), aw, Math.min(ah, size.h));
  case "maxH": return R(Math.max(ax, size.x), ay, Math.min(aw, size.w), ah);
  // the middle, at the size it has (`size`) or the size asked
  case "size":
  case "center": {
    const w = Math.min(aw, size.w), h = Math.min(ah, size.h);
    return R(ax + (aw - w) / 2, ay + (ah - h) / 2, w, h);
  }
  case "left": return R(ax, ay, aw / 2 - half, ah);
  case "right": return R(ax + aw / 2 + half, ay, aw / 2 - half, ah);
  case "top": return R(ax, ay, aw, ah / 2 - half);
  case "bottom": return R(ax, ay + ah / 2 + half, aw, ah / 2 - half);
  case "max": return R(ax, ay, aw, ah);
  }
  return null;
}
// Hyprland's gaps_out as `hyprctl getoption -j` says it: a number, or a
// css-like "20 20 20 20" (the first is enough: the sides are even here)
function gapsOf(text) {
  try {
    const j = JSON.parse(String(text || ""));
    const v = j.int !== undefined ? j.int : j.custom !== undefined ? j.custom : j.css !== undefined ? j.css : j.str;
    const n = parseInt(String(v).trim().split(/\s+/)[0], 10);
    return isNaN(n) ? 0 : n;
  } catch (e) { return 0; }
}

// ── DARK MODE, LIGHT MODE (2026-11-03) ───────────────────────────────────
// The theme on the other side of the one worn: its family's own (Gruvbox
// Dark ↔ Gruvbox Light, Tokyo Night ↔ Tokyo Night Day), else the name with
// dark and light (day and night) swapped, else Zenon's. `options` is
// Oracle's themeOptions ({ value, light }); null when it is already that side.
const THEME_PAIRS = { "zenon": "zenon-light", "ayu-dark": "ayu-light", "ayu-mirage": "ayu-light",
  "catppuccin-mocha": "catppuccin-latte", "catppuccin-macchiato": "catppuccin-latte", "catppuccin-frappe": "catppuccin-latte",
  "nightfox": "dayfox", "kanagawa-wave": "kanagawa-lotus", "kanagawa-dragon": "kanagawa-lotus",
  "rose-pine": "rose-pine-dawn", "rose-pine-moon": "rose-pine-dawn", "tokyo-night": "tokyo-night-day",
  "tokyo-night-storm": "tokyo-night-day", "one-dark": "one-light" };
function themeSide(current, wantLight, options) {
  const opts = options || [];
  const has = (v) => opts.some((o) => o.value === v);
  const isLight = (v) => v === "zenon-light" || opts.some((o) => o.value === v && o.light);
  if (isLight(current) === wantLight) return null;
  // the pair either way round (a light theme's first dark partner)
  for (const dark in THEME_PAIRS) {
    if (wantLight && dark === current && has(THEME_PAIRS[dark])) return THEME_PAIRS[dark];
    if (!wantLight && THEME_PAIRS[dark] === current && has(dark)) return dark;
  }
  const swaps = wantLight ? [["dark", "light"], ["night", "day"]] : [["light", "dark"], ["day", "night"]];
  for (const [a, b] of swaps) {
    const v = String(current).replace(new RegExp("\\b" + a + "\\b"), b);
    if (v !== current && has(v) && isLight(v) === wantLight) return v;
  }
  return wantLight ? "zenon-light" : "zenon";
}

// ── PROCESSES AND PORTS (2026-11-02) ──────────────────────────────────────
// "ps …": what runs, the busiest first (ps -eo pid=,pcpu=,rss=,comm=,args=);
// "port 8080": what listens there (ss -ltnupH). Return ends it, on the
// one-line confirm.
function processRows(text, query, self) {
  const q = String(query || "").trim().toLowerCase();
  const out = [];
  for (const line of String(text || "").split("\n")) {
    const m = /^\s*(\d+)\s+([\d.]+)\s+(\d+)\s+(\S+)\s*(.*)$/.exec(line);
    if (!m || +m[1] === self) continue;
    const name = m[4], args = m[5] || name;
    if (q !== "" && (name + " " + args).toLowerCase().indexOf(q) < 0 && m[1] !== q) continue;
    const mb = Math.round(+m[3] / 1024);
    out.push({ kind: "proc", key: "proc:" + m[1], pid: +m[1], name, text: name, label: name,
      sub: "PID " + m[1] + " · " + m[2] + "% CPU · " + (mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : mb + " MB"),
      args, glyph: "", section: "Processes" });
    if (out.length >= 40) break;
  }
  return out;
}
function portRows(text, port) {
  const out = [];
  const seen = {};
  for (const line of String(text || "").split("\n")) {
    const f = line.trim().split(/\s+/);
    if (f.length < 5) continue;
    const local = f[4];
    if (!new RegExp(":" + port + "$").test(local)) continue;
    const who = /users:\(\("([^"]+)",pid=(\d+)/.exec(line);
    const key = (who ? who[2] : "?") + f[0];
    if (seen[key]) continue;
    seen[key] = true;
    out.push({ kind: "proc", key: "port:" + key, pid: who ? +who[2] : 0, name: who ? who[1] : "",
      text: who ? who[1] : local, label: who ? who[1] : "Something you cannot see (another user's)",
      sub: f[0].toUpperCase() + " " + local + (who ? " · PID " + who[2] : ""), args: "", glyph: "\u{F0317}",
      section: "Port " + port });
  }
  return out;
}

// ── BLUETOOTH AND WI-FI (2026-11-02) ──────────────────────────────────────
// "bt …" and "wifi …": the control hub's own lists (Hermes.devices and
// Hermes.networks, with their glyphs); return connects or leaves
function deviceRows(devices, query) {
  const q = String(query || "").trim().toLowerCase();
  return (devices || []).filter((d) => d.named && (q === "" || d.name.toLowerCase().indexOf(q) >= 0))
    .map((d) => ({ kind: "btdev", key: "bt:" + d.name, dev: d, text: d.name, label: d.name, glyph: d.glyph,
      sub: [d.busy ? "Busy…" : d.connected ? "Connected" : d.paired ? "Paired" : "Not paired",
        d.battery >= 0 ? d.battery + "% battery" : ""].filter((x) => x).join(" · "), section: "Bluetooth" }));
}
function networkRows(networks, query) {
  const q = String(query || "").trim().toLowerCase();
  return (networks || []).filter((n) => n.name && (q === "" || n.name.toLowerCase().indexOf(q) >= 0))
    .map((n) => ({ kind: "wifinet", key: "wifi:" + n.name, net: n, text: n.name, label: n.name, glyph: n.glyph,
      sub: [n.busy ? "Joining…" : n.connected ? "Connected" : n.known ? "Known" : "", n.secure ? "Secured" : "Open"]
        .filter((x) => x).join(" · "), section: "Wi-Fi" }));
}

// ── REPOSITORIES (2026-11-02) ─────────────────────────────────────────────
// "repo …": Delphi's recent repositories (delphi.json recents), with what
// git says of each (git status --porcelain=v2 --branch, by root: dirty,
// ahead, behind, the branch); return opens it in Delphi
function repoStatus(text) {
  const out = {};
  for (const rec of String(text || "").split("\u001e")) {
    const lines = rec.split("\n");
    const root = lines[0].trim();
    if (root === "") continue;
    const s = { branch: "", ahead: 0, behind: 0, changed: 0, ok: false };
    for (const l of lines.slice(1)) {
      let m;
      if ((m = /^# branch\.head (.+)$/.exec(l))) { s.branch = m[1]; s.ok = true; }
      else if ((m = /^# branch\.ab \+(\d+) -(\d+)$/.exec(l))) { s.ahead = +m[1]; s.behind = +m[2]; }
      else if (/^[12u?] /.test(l)) s.changed++;
    }
    out[root] = s;
  }
  return out;
}
function repoStatusCommand() {
  return "for r in \"$@\"; do printf '\\036%s\\n' \"$r\"; git -C \"$r\" status --porcelain=v2 --branch 2>/dev/null; done";
}
function repoRows(recents, status, query, home) {
  const q = String(query || "").trim().toLowerCase();
  return (recents || []).filter((r) => q === "" || (r.name + " " + r.root).toLowerCase().indexOf(q) >= 0)
    .map((r) => {
      const s = (status || {})[r.root];
      const facts = !s ? [] : !s.ok ? ["Not a repository now"] : [s.branch,
        s.changed > 0 ? s.changed + " changed" : "clean", s.ahead > 0 ? s.ahead + " to push" : "",
        s.behind > 0 ? s.behind + " to pull" : ""].filter((x) => x);
      return { kind: "repo", key: "repo:" + r.root, path: r.root, text: r.name, label: r.name,
        sub: [Artemis.shownPath(r.root, home)].concat(facts).join(" · "),
        glyph: s && s.ok && s.changed > 0 ? "\u{F02A2}" : "", section: "Repositories" };
    });
}

// ── SERVICES (2026-11-02) ─────────────────────────────────────────────────
// "svc …": systemd's services, the system's and yours (Hestia's own reading,
// hestia.py units); the failed first, then the running; return opens it in
// Hestia, its actions start, stop and restart it
function serviceRows(units, query) {
  const q = String(query || "").trim().toLowerCase();
  const rank = (u) => u.active === "failed" ? 0 : u.active === "active" ? 1 : 2;
  return (units || []).filter((u) => q === "" || (u.unit + " " + (u.desc || "")).toLowerCase().indexOf(q) >= 0)
    .slice().sort((a, b) => rank(a) - rank(b) || (a.unit < b.unit ? -1 : 1))
    .slice(0, 60)
    .map((u) => ({ kind: "svc", key: "svc:" + u.scope + ":" + u.unit, unit: u.unit, scope: u.scope,
      active: u.active, text: u.unit.replace(/\.service$/, ""), label: u.unit.replace(/\.service$/, ""),
      sub: [u.active === "active" ? (u.sub === "running" ? "Running" : "Active") : u.active === "failed" ? "Failed" : "Stopped",
        u.scope === "user" ? "yours" : "", u.desc || ""].filter((x) => x).join(" · "),
      glyph: u.active === "failed" ? "" : u.active === "active" ? "" : "",
      section: u.active === "failed" ? "Failed" : "Services" }));
}

// ── NOTIFICATIONS (2026-11-02) ────────────────────────────────────────────
// "notif …": Howler's history, the newest first; return does what its toast
// did (Howler.openRow), its actions copy it or forget it
function notifRows(history, query, now) {
  const q = String(query || "").trim().toLowerCase();
  const at = (now || new Date()).getTime();
  const ago = (t) => {
    const m = Math.round((at - t) / 60000);
    return m < 1 ? "Now" : m < 60 ? m + " min ago" : m < 1440 ? Math.round(m / 60) + " h ago" : Math.round(m / 1440) + " d ago";
  };
  const plain = (s) => String(s || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
  return (history || []).filter((h) => q === "" || (h.appName + " " + h.summary + " " + plain(h.body)).toLowerCase().indexOf(q) >= 0)
    .slice().sort((a, b) => (b.time || 0) - (a.time || 0))
    .slice(0, 60)
    .map((h) => ({ kind: "notif", key: "notif:" + h.id + ":" + h.time, row: h, text: plain(h.summary) || h.appName,
      label: plain(h.summary) || h.appName, body: plain(h.body),
      sub: [h.appName, ago(h.time || 0), plain(h.body).slice(0, 80)].filter((x) => x).join(" · "),
      glyph: "", section: "Notifications" }));
}

// ── CLIPBOARD TRANSFORMS (2026-11-02) ─────────────────────────────────────
// A text clip pasted otherwise (shift return, "Paste as"): the text as it
// is changed, or null when that change cannot be made (JSON that is not)
const TRANSFORMS = [
  { id: "upper", text: "UPPER CASE" }, { id: "lower", text: "lower case" }, { id: "title", text: "Title Case" },
  { id: "slug", text: "slug-case" }, { id: "trim", text: "Trimmed, one line" }, { id: "sort", text: "Lines sorted" },
  { id: "json", text: "Pretty JSON" }, { id: "b64", text: "Base64" }
];
function transformText(id, t) {
  const s = String(t || "");
  switch (id) {
  case "upper": return s.toUpperCase();
  case "lower": return s.toLowerCase();
  // no \p{L}: Qt's engine takes it without a word and matches nothing
  // (2026-11-02 audit). A word's first character, whatever it is: upper
  // case leaves a digit or a mark as it was.
  case "title": return s.toLowerCase().replace(/(^|[\s\-("'])([^\s\-("'])/g, (m, a, b) => a + b.toUpperCase());
  case "slug": return s.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  case "trim": return s.replace(/\s+/g, " ").trim();
  case "sort": return s.split("\n").filter((l) => l.trim() !== "")
    .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" })).join("\n");
  case "json":
    try { return JSON.stringify(JSON.parse(s), null, 2); } catch (e) { return null; }
  case "b64": return Answers.b64encode(s);
  }
  return null;
}

// ── SCRIPTS THAT LIST, SCRIPTS THAT SAY (2026-11-02) ──────────────────────
// Two more @modes for your scripts:
//   # @mode list      its word and a space make a list of what it prints,
//                     run again (with the words after, as $1) as you type
//   # @mode inline    what it prints is its row's second line, run on every
//                     open; `# @refresh 30s` runs it again while the panel
//                     is up (s, m, h; a bare number is seconds)
// A list script prints JSON — an array, or { "items": [...] }, or one
// object a line — each { title, subtitle, glyph, copy, open, paste, run };
// plain lines are each a title that copies itself. Return opens `open` (a
// link or a path), else pastes `paste`, else runs `run` (a shell line),
// else copies `copy` (else the title).
function refreshMs(s) {
  const m = /^\s*(\d+(?:\.\d+)?)\s*(s|sec|secs|seconds?|m|min|mins|minutes?|h|hours?)?\s*$/i.exec(String(s || ""));
  if (!m) return 0;
  const u = (m[2] || "s").charAt(0).toLowerCase();
  return Math.max(1000, Math.round(+m[1] * (u === "h" ? 3600000 : u === "m" ? 60000 : 1000)));
}
function scriptListFor(scripts, query) {
  const m = /^\s*(\S+)\s(.*)$/.exec(String(query || ""));
  if (!m) return null;
  const word = m[1].toLowerCase();
  const sc = (scripts || []).find((x) => x.mode === "list" && x.word === word);
  return sc ? { script: sc, arg: m[2].trim() } : null;
}
function parseListItems(text) {
  const t = String(text || "").trim();
  if (t === "") return [];
  const clean = (o) => o && typeof o === "object" && (o.title !== undefined || o.copy !== undefined)
    ? { title: String(o.title !== undefined ? o.title : o.copy), subtitle: String(o.subtitle || ""),
        glyph: String(o.glyph || ""), copy: o.copy !== undefined ? String(o.copy) : "",
        open: String(o.open || ""), paste: String(o.paste || ""), run: String(o.run || "") }
    : null;
  try {
    const j = JSON.parse(t);
    const list = Array.isArray(j) ? j : j && Array.isArray(j.items) ? j.items : null;
    if (list) return list.map(clean).filter((x) => x);
  } catch (e) {}
  const out = [];
  for (const line of t.split("\n")) {
    const l = line.trim();
    if (l === "") continue;
    let o = null;
    if (l.charAt(0) === "{") { try { o = clean(JSON.parse(l)); } catch (e) {} }
    out.push(o || { title: l, subtitle: "", glyph: "", copy: l, open: "", paste: "", run: "" });
  }
  return out;
}
function listItemRows(sc, items) {
  return (items || []).slice(0, 100).map((it, i) => ({ kind: "sitem", key: "sitem:" + i + ":" + it.title, item: it,
    text: it.title, label: it.title, sub: it.subtitle, glyph: it.glyph || sc.glyph, section: sc.title }));
}

// ── WORDS INSIDE FILES (2026-11-02) ───────────────────────────────────────
// "in …": ripgrep through your own files for the words (three letters or
// more), smart case as terminus' content search; not the hidden directories
// — apps keep hundreds of thousands of files there (.config's browsers and
// chat apps, .rustup), and a word found nowhere took 18 s instead of a
// hundredth (2026-11-02) — but your zenworks config, which is yours. A row
// a matching line; return opens it at that line in Plato.
function contentCommand(query, home) {
  const h = Strings.shellQuote(home);
  return "rg --line-number --no-heading --smart-case --color=never --max-columns 300"
    + " --max-columns-preview --max-count 5 --max-filesize 2M -g '!node_modules'"
    + " -- " + Strings.shellQuote(query) + " " + h + " $( [ -d " + h + "/.config/zenworks ] && printf '%s' " + h + "/.config/zenworks )"
    + " 2>/dev/null | head -n 80";
}
function contentRows(text, home, glyphOf) {
  const out = [];
  for (const line of String(text || "").split("\n")) {
    const m = /^(.+?):(\d+):(.*)$/.exec(line);
    if (!m) continue;
    const shown = Artemis.shownPath(m[1], home);
    out.push({ kind: "hit", key: "hit:" + m[1] + ":" + m[2], path: m[1], line: +m[2],
      text: m[3].trim(), label: m[3].trim().slice(0, 160) || "(an empty line)",
      sub: shown + ":" + m[2], glyph: (glyphOf ? glyphOf({ name: Artemis.basename(m[1]), isDir: false, path: m[1] }) : "") || "",
      section: "Matches" });
  }
  return out;
}

// ── FONTS (2026-11-02) ────────────────────────────────────────────────────
// "font …": the installed families (Alexandria's own reading of fc-list,
// alexandria.js parseList) as a grid, Raycast's (user, 2026-11-03):
// `perRow` tiles a row, each the family's name in itself; a tile is what a
// font row was (kind "font"), and return opens it in Alexandria
function fontRows(families, query, perRow) {
  const q = String(query || "").trim().toLowerCase();
  const items = (families || []).filter((f) => q === "" || f.name.toLowerCase().indexOf(q) >= 0)
    .slice(0, 60)
    .map((f) => ({ kind: "font", id: f.name, family: f.name, files: f.files, face: f.variants[0] || f.name,
      text: f.name, label: f.name, name: f.name,
      sub: [f.styles.length + (f.styles.length === 1 ? " style" : " styles"), f.mono ? "monospace" : "",
        f.nerd ? "nerd glyphs" : "", f.user ? "yours" : ""].filter((x) => x).join(" \u00B7 ") }));
  const per = Math.max(1, perRow || 4);
  const out = [];
  for (let i = 0; i < items.length; i += per)
    out.push({ kind: "fonts", key: "fonts:" + items[i].family, section: "Fonts", text: "", label: "",
      cells: items.slice(i, i + per) });
  return out;
}

// ── SCREENSHOTS AND RECORDINGS (2026-11-02) ───────────────────────────────
// "shots …" (Picasso's ~/Pictures/Screenshots) and "rec …" (Argus'
// ~/Videos/Captures) as the clipboard's pictures are: a grid of thumbnails,
// newest first, found by file name. `found` is "mtime<TAB>path" lines;
// `thumbs` the morpheus pool's path → thumbnail.
function captureRows(found, query, thumbs, perRow, video) {
  const q = String(query || "").trim().toLowerCase();
  const items = [];
  for (const line of String(found || "").split("\n")) {
    const cut = line.indexOf("\t");
    if (cut < 0) continue;
    const path = line.slice(cut + 1);
    const name = path.slice(path.lastIndexOf("/") + 1);
    if (q !== "" && name.toLowerCase().indexOf(q) < 0) continue;
    const t = (thumbs || {})[path];
    items.push({ path, name, video: !!video, thumb: t === undefined ? "" : t === "-" ? (video ? "" : path) : t,
      stamp: stampOf(Number(line.slice(0, cut)) * 1000) });
  }
  const per = Math.max(1, perRow || 4);
  const out = [];
  for (let i = 0; i < items.length; i += per)
    out.push({ kind: "shots", key: "shots:" + items[i].path, section: video ? "Recordings" : "Screenshots",
      text: "", label: "", cells: items.slice(i, i + per).map((c) => Object.assign({ id: c.path }, c)) });
  return out;
}
const MONTH3 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function stampOf(ms) {
  const d = new Date(ms);
  const two = (n) => (n < 10 ? "0" : "") + n;
  return d.getDate() + " " + MONTH3[d.getMonth()] + ", " + two(d.getHours()) + ":" + two(d.getMinutes());
}
function capturesCommand(video) {
  return video
    ? "v=$(xdg-user-dir VIDEOS 2>/dev/null); { [ -n \"$v\" ] && [ \"$v\" != \"$HOME\" ]; } || v=\"$HOME/Videos\"; "
      + "find \"$v/Captures\" -maxdepth 1 -type f \\( -name '*.mp4' -o -name '*.mkv' -o -name '*.webm' -o -name '*.gif' \\) "
      + "-printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -n 60 | sed 's/^\\([0-9]*\\)\\.[0-9]*/\\1/'"
    : "p=$(xdg-user-dir PICTURES 2>/dev/null); { [ -n \"$p\" ] && [ \"$p\" != \"$HOME\" ]; } || p=\"$HOME/Pictures\"; "
      + "find \"$p/Screenshots\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) "
      + "-printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -n 60 | sed 's/^\\([0-9]*\\)\\.[0-9]*/\\1/'";
}

// ── HELP (2026-11-02) ─────────────────────────────────────────────────────
// "?" or "help": every word Cynosure answers to and every phrase it reads,
// in groups, the word on a cap at the row's end (user: "in case i forgot a
// command"). "? weather" / "help todo" finds among them. Return types the
// word (or the phrase's start) into the line; a key is only said.
//   [group, word on the cap, what it does, an example, what return types]
const HELP = [
  ["Find", "f", "Files by name", "f invoice", "f "],
  ["Find", "in", "Words inside your files", "in TODO", "in "],
  ["Find", "go", "Bookmarks, network places, directories you use", "go projects", "go "],
  ["Find", "win", "Open windows", "win firefox", "win "],
  ["Find", "cb", "The clipboard and snippets (also: cb links, files, colors, pinned)", "cb pictures", "cb "],
  ["Find", "notes", "Clio's notes", "notes #work", "notes "],
  ["Find", "todos", "Open tasks (also: tasks)", "todos", "todos "],
  ["Find", "book", "Minerva's library", "book dune", "book "],
  ["Find", "font", "Installed fonts", "font mono", "font "],
  ["Find", "shots", "Screenshots", "shots", "shots "],
  ["Find", "rec", "Recordings", "rec", "rec "],
  ["Find", "colors", "Colors you picked", "colors", "colors "],
  ["Find", "notif", "Notification history", "notif ceres", "notif "],
  ["Find", "bm", "Your browsers' bookmarks", "bm arch wiki", "bm "],
  ["Find", "browsed", "Your browsers' history", "browsed reddit", "browsed "],
  ["Find", "github", "Notifications, pull requests, issues (also: prs, issues)", "prs zenworks", "github "],
  ["Find", "music", "Music on this computer (also: videos)", "music miles", "music "],
  ["Find", "menu", "The tray apps' menus", "menu pause", "menu "],
  ["Find", "contacts", "Your contacts (~/Documents/Contacts, and synced ones)", "contacts ada", "contacts "],
  ["Find", "settings", "Settings", "settings font size", "settings "],
  ["Find", "store", "Apps in the store (also: install)", "store gimp", "store "],
  ["Find", "pkg", "Every package and the AUR", "pkg htop", "pkg "],
  ["Find", "repo", "Delphi's repositories", "repo zenworks", "repo "],
  ["Find", "svc", "Services", "svc bluetooth", "svc "],
  ["Find", "ps", "Running processes", "ps firefox", "ps "],
  ["Find", "port", "What listens on a port", "port 8080", "port "],
  ["Find", "output", "Sound outputs", "output", "output "],
  ["Find", "bt", "Bluetooth devices", "bt buds", "bt "],
  ["Find", "wifi", "Wi-Fi networks", "wifi", "wifi "],
  ["Find", "em", "Emoji (also: a colon, :heart)", "em heart", "em "],
  ["Find", "nf", "Nerd glyphs", "nf folder", "nf "],
  ["Find", "pw", "Passwords", "pw github", "pw "],
  ["Make", "note", "A new note", "note buy milk", "note "],
  ["Make", "todo", "A new task", "todo pay rent friday", "todo "],
  ["Make", "remind me", "A reminder", "remind me in 20 min to call mom", "remind me "],
  ["Make", "event", "A calendar event", "event lunch friday 1pm", "event "],
  ["Make", "timer", "A timer (also: pomodoro)", "timer 25m tea", "timer "],
  ["Make", "new contact", "A contact: a name, then an email or a phone number", "new contact Ada Lovelace ada@example.org", "new contact "],
  ["Make", "confetti", "A burst of confetti (also: celebrate)", "confetti", "confetti"],
  ["Do", "camera", "Your camera, mirrored, in a window (also: mirror)", "camera", "camera"],
  ["Make", "focus", "A focus session: do not disturb, apps set aside", "focus 50m writing", "focus "],
  ["Make", "focus block", "An app set aside while you focus (also: focus allow)", "focus block discord", "focus block "],
  ["Make", "end focus", "Ends the session early", "end focus", "end focus"],
  ["Make", "auto quit", "An app quit after a while unused (also: auto quit … off)", "auto quit slack after 1h", "auto quit "],
  ["Make", "take a break", "A five-minute break", "take a break for 10 min", "take a break"],
  ["Ask", "calc", "The calculator; numbers, units and currencies work anywhere", "12% of 80, 5 usd to eur", "calc "],
  ["Ask", "def", "A word's meaning (also: define)", "def serendipity", "def "],
  ["Ask", "tr", "A translation (also: translate)", "tr hello in spanish", "tr "],
  ["Ask", "weather", "The weather here or anywhere", "weather in paris tomorrow", "weather"],
  ["Ask", "time", "The time here or anywhere", "time in tokyo", "time"],
  ["Ask", "what's on", "Your calendar", "what's on tomorrow", "what's on "],
  ["Ask", "screen time", "Kairos' count", "how long on firefox today", "screen time"],
  ["Ask", "battery", "Also: ip, uptime, memory, disk, cpu, kernel", "battery", "battery"],
  ["Ask", "rgb()", "A color in other forms (also: a hex color, hsl())", "rgb(255, 136, 0)", "rgb("],
  ["Ask", "base64", "Also: url encode, md5, sha256, count, lorem", "base64 hello", "base64 "],
  ["Ask", "qr", "A QR code of the words", "qr https://example.com", "qr "],
  ["Ask", "speed test", "How fast the connection is", "speed test", "speed test"],
  ["Ask", "coin", "Also: dice, d20, random 1 100, uuid, moon, week", "flip a coin", "flip a coin"],
  ["Ask", "playing", "What is playing", "what's playing", "what's playing"],
  ["Do", "volume", "Volume to a level, up or down (also: mute)", "volume 30", "volume "],
  ["Do", "brightness", "Brightness (also: brighter, dimmer)", "brightness 50", "brightness "],
  ["Do", "wifi on", "Also: bluetooth, night light, dnd — on or off", "wifi off", "wifi "],
  ["Do", "play", "Also: pause, next, previous", "next", "next"],
  ["Do", "workspace", "Go to a workspace", "workspace 3", "workspace "],
  ["Do", "move to workspace", "Takes the window you were in there (also: send window to)", "move to workspace 3", "move to workspace "],
  ["Do", "quit", "End an app (also: force quit)", "quit firefox", "quit "],
  ["Do", "restart", "End an app and open it again", "restart firefox", "restart "],
  ["Do", "screenshot", "After a wait (also: a window, a region)", "screenshot a window in 3s", "screenshot "],
  ["Do", "snap", "Every place the window you were in can go, as a list", "snap", "snap "],
  ["Do", "left half", "The window you were in (also: right, top, bottom half)", "left half", "left half"],
  ["Do", "maximize", "Fill the screen (also: almost maximize, next screen, size 1280x720)", "maximize", "maximize"],
  ["Do", "left third", "Also: center, right third, left two thirds, center half", "left third", "left third"],
  ["Do", "top left quarter", "Also: top right, bottom left, bottom right", "top left quarter", "top left quarter"],
  ["Do", "center", "The window in the middle, at its size", "center", "center"],
  ["Do", "restore", "The window back where it was before", "restore", "restore"],
  ["Do", "larger", "The window a tenth larger (also: smaller, maximize width, maximize height)", "larger", "larger"],
  ["Do", "fullscreen", "The window full screen, or back (also: previous screen)", "fullscreen", "fullscreen"],
  ["Do", "dark mode", "The theme's dark side (also: light mode, toggle appearance)", "dark mode", "dark mode"],
  ["Do", "theme", "Every theme as Oracle lists it, and dark or light mode", "theme nord", "theme "],
  ["Do", "show desktop", "An empty workspace", "show desktop", "show desktop"],
  ["Do", "quit all", "Closes every window", "quit all apps", "quit all apps"],
  ["Do", "empty trash", "Deletes what is in the trash for good", "empty trash", "empty trash"],
  ["Do", "eject", "Every removable drive, safe to unplug", "eject", "eject"],
  ["Do", "screens off", "Until a key is pressed", "screens off", "screens off"],
  ["Do", "clear clipboard", "Forgets the clipboard history (pins stay)", "clear clipboard", "clear clipboard"],
  ["Do", "join meeting", "Opens the link of the next meeting on your calendar", "join meeting", "join meeting"],
  ["Do", "save layout", "Where every window is, kept by name (also: forget layout)", "save layout coding", "save layout "],
  ["Do", "layout", "Puts the windows back as saved, opening what is missing", "layout coding", "layout "],
  ["Do", "clear layouts", "Forgets every saved layout", "clear layouts", "clear layouts"],
  ["Do", "clear window places", "Forgets where windows were, for restore", "clear window places", "clear window places"],
  ["Do", "ocr", "Copy the text in a region of the screen", "copy text from screen", "ocr"],
  ["Do", "scan qr", "Read a QR code on the screen", "scan qr", "scan qr"],
  ["Do", "an address", "Opens in the browser", "github.com", ""],
  ["Make", "{argument}", "In a snippet, a value asked for each time: {argument name=\"client\" default=\"Acme\"}", "", ""],
  ["Keys", "shift return", "What else the chosen row can do: hide it, move a fallback, the browser a link opens in", "", ""],
  ["Keys", "alt 1", "Opens that row at once (alt 1 to alt 9)", "", ""],
  ["Find", "history", "What you searched before, to search again", "history", "history "],
  ["Keys", "tab", "Completes a name; on a word like def, win or quit, makes it a chip so only its own list shows", "", ""],
  ["Keys", "tab again", "With a chip in place: moves it on to the next of its kin (Windows, Snap, Quit, Layouts); shift tab goes back", "", ""],
  ["Keys", "backspace", "On an empty line: takes the chip away", "", ""],
  ["Keys", "down", "On the empty compact field: shows your favorites and suggestions", "", ""],
  ["Keys", "esc", "Clears the line, then closes", "", ""],
  ["Keys", "super shift space", "Opens on the text you copied", "", ""]
];
// `own`: { aliases, links, scripts } — your words, under their own heading
function helpRows(query, own) {
  const q = String(query || "").trim().toLowerCase();
  const rows = HELP.map((h) => ({ group: h[0], word: h[1], label: h[2], sub: h[3], fill: h[4] }));
  const o = own || {};
  for (const w in o.aliases || {}) rows.push({ group: "Your words", word: w, label: o.aliases[w].label || "", sub: "", fill: w });
  for (const l of o.links || []) rows.push({ group: "Quick links", word: l.word, label: "Search " + l.name, sub: l.word + " …", fill: l.word + " " });
  for (const sc of o.scripts || []) if (sc.argument || sc.mode === "list")
    rows.push({ group: "Your scripts", word: sc.word, label: sc.title, sub: sc.argument ? sc.word + " " + sc.argument : "", fill: sc.word + " " });
  const glyph = { Find: "", Make: "", Ask: "", Do: "", Keys: "",
    "Your words": "", "Quick links": "", "Your scripts": "" };
  return rows.filter((r) => q === "" || (r.word + " " + r.label + " " + r.sub).toLowerCase().indexOf(q) >= 0)
    .map((r, i) => ({ kind: "help", key: "help:" + i + ":" + r.word, text: r.label, label: r.label, sub: r.sub,
      cap: r.word, fill: r.fill, glyph: glyph[r.group] || "", section: r.group }));
}

// ── FAVORITES (2026-11-02) ────────────────────────────────────────────────
// Rows you keep at the top of the empty line, in the order given (Raycast's
// favorites): kept as a hotkey keeps its row (hotkeyRow), found again by
// kind and key (hotkeyTarget).
//   [{ kind, key, label, … }]
function favoritesPath() {
  return Paths.dataDir() + "/cynosure-favorites.json";
}
function parseFavorites(text) {
  try {
    const j = JSON.parse(String(text || "") || "[]");
    return Array.isArray(j) ? j.filter((r) => r && HOTKEY_KINDS[r.kind]) : [];
  } catch (e) { return []; }
}
function serializeFavorites(list) {
  return JSON.stringify(list || [], null, 2) + "\n";
}
function isFavorite(list, row) {
  const t = hotkeyTarget(row);
  return (list || []).some((f) => hotkeyTarget(f) === t);
}
function addFavorite(list, row) {
  return isFavorite(list, row) ? (list || []).slice() : (list || []).concat([hotkeyRow(row)]);
}
function dropFavorite(list, row) {
  const t = hotkeyTarget(row);
  return (list || []).filter((f) => hotkeyTarget(f) !== t);
}
// one place up (by -1) or down (by 1)
function moveFavorite(list, row, by) {
  const out = (list || []).slice();
  const i = out.findIndex((f) => hotkeyTarget(f) === hotkeyTarget(row));
  const j = i + by;
  if (i < 0 || j < 0 || j >= out.length) return out;
  const x = out[i]; out[i] = out[j]; out[j] = x;
  return out;
}
// the kept rows as the list has them now (a verb's live face); a file, a
// link's search or a script's run as kept; an app since removed, not at all
const KEPT_WHOLE = { file: true, link: true, script: true };
function favoriteRows(list, rows) {
  const out = [];
  for (const f of list || []) {
    const t = hotkeyTarget(f);
    const live = KEPT_WHOLE[f.kind] ? null : (rows || []).find((r) => hotkeyTarget(r) === t);
    if (live || KEPT_WHOLE[f.kind]) out.push(live || f);
  }
  return out;
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
// the quick links with `word` opened in `app` (a .desktop id, "" for the
// default browser): your own link changed, a built-in kept as a stand-in
// that says only which app (allLinks puts the built-in under it)
function withLinkApp(own, word, app, appName) {
  const list = (own || []).slice();
  const at = list.findIndex((l) => l.word === word);
  const builtin = QUICKLINKS.find((x) => x.word === word);
  if (at >= 0 && !list[at].builtin) {
    list[at] = Object.assign({}, list[at], { app: app || "", appName: app ? appName || "" : "" });
    if (!app) { delete list[at].app; delete list[at].appName; }
    return list;
  }
  if (at >= 0) list.splice(at, 1);
  if (app && builtin) list.push({ word, url: builtin.url, builtin: true, app, appName: appName || "" });
  return list;
}
// `grep -H ^Name=` over the .desktop files that take https: [{ id, name }]
function parseBrowsers(text) {
  const out = [];
  const seen = {};
  for (const line of String(text || "").split("\n")) {
    const m = /([^/]+)\.desktop:Name=(.+)$/.exec(line);
    if (!m || seen[m[1]]) continue;
    seen[m[1]] = true;
    out.push({ id: m[1], name: m[2].trim() });
  }
  return out;
}
function serializeLinks(list) {
  return JSON.stringify(list || [], null, 2) + "\n";
}
// the built-ins with yours over them (yours marked `own`)
// Oracle's Web search (Cynosure › Search): where "web …" goes, unless a
// quick link of your own is named web
const WEB_ENGINES = {
  duckduckgo: { url: "https://duckduckgo.com/?q={q}", home: "https://duckduckgo.com" },
  google: { url: "https://www.google.com/search?q={q}", home: "https://www.google.com" },
  brave: { url: "https://search.brave.com/search?q={q}", home: "https://search.brave.com" },
  startpage: { url: "https://www.startpage.com/do/search?q={q}", home: "https://www.startpage.com" },
  kagi: { url: "https://kagi.com/search?q={q}", home: "https://kagi.com" },
  bing: { url: "https://www.bing.com/search?q={q}", home: "https://www.bing.com" },
  ecosia: { url: "https://www.ecosia.org/search?q={q}", home: "https://www.ecosia.org" }
};
function allLinks(own, engine) {
  const out = [];
  const mine = {};
  const web = WEB_ENGINES[engine];
  for (const l of own || []) mine[l.word] = true;
  for (const l of QUICKLINKS) if (!mine[l.word]) out.push(l.word === "web" && web ? Object.assign({}, l, web) : l);
  for (const l of own || []) {
    // a built-in kept only for the app it opens in (2026-11-04): the
    // built-in itself, today's engine and all, with that app
    const b = l.builtin ? QUICKLINKS.find((x) => x.word === l.word) : null;
    if (l.builtin && !b) continue;
    out.push(b ? Object.assign({}, b, b.word === "web" && web ? web : {}, { app: l.app || "", appName: l.appName || "", own: true, builtin: true })
      : Object.assign({ glyph: "\uF0C1" }, l, { own: true }));
  }
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
// `{clipboard}` and `{selection}` (2026-11-03) are filled when it opens
// (fillLinkFrom): a link of those alone opens as it is
const FROM_DESK = /\{(clipboard|selection)\}/;
function linkUrl(l, rest) {
  const q = String(rest || "").trim();
  if (q === "" && FROM_DESK.test(l.url) && l.url.indexOf("{q}") < 0) return l.url;
  if (q === "") return l.home || (/^https?:\/\/[^/]+/i.exec(l.url) || [l.url])[0];
  return l.url.indexOf("{q}") >= 0 ? l.url.split("{q}").join(encodeURIComponent(q)) : l.url;
}
function wantsDesk(url) { return FROM_DESK.test(String(url || "")); }
function fillLinkFrom(url, clip, sel) {
  return String(url).split("{clipboard}").join(encodeURIComponent(String(clip || "").trim()))
    .split("{selection}").join(encodeURIComponent(String(sel || "").trim()));
}
function linkRow(l, rest, section) {
  const q = String(rest || "").trim();
  return { kind: "link", key: "link:" + l.word, word: l.word, own: !!l.own, builtin: !!l.builtin,
    app: l.app || "", appName: l.appName || "", url: linkUrl(l, q),
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
  "store", "install", "notes", "note", "pkg", "event", "todo", "todos", "tasks", "book", "books", "output",
  "colors", "go", "ps", "port", "bt", "wifi", "repo", "svc", "notif", "in", "font", "shots", "rec", "help", "?",
  "bm", "browsed", "github", "prs", "issues", "music", "videos", "menu", "qr", "focus", "layout", "layouts",
  "contact", "contacts", "confetti", "camera", "history", "quit", "snap", "snaps", "theme", "themes"];
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
  // after the launcher has gone, so it is not in the picture ("screenshot 5"
  // waits: answers.js parseCommand)
  { name: "Screenshot the screen", glyph: "\u{F0E51}", keys: "picasso screenshot screen shot capture print", sh: "sleep 0.35 && qs ipc call Picasso shot screen" },
  { name: "Screenshot a window", glyph: "\u{F0614}", keys: "picasso screenshot window shot capture print", sh: "sleep 0.35 && qs ipc call Picasso shot window" },
  { name: "Screenshot a region", glyph: "\u{F0A6D}", keys: "picasso screenshot region area selection shot capture print", sh: "sleep 0.35 && qs ipc call Picasso shot region" },
  { name: "Colors you picked", glyph: "\u{F03D8}", keys: "picasso palette picker eyedropper colours hex", line: "colors " },
  { name: "Measure on screen", glyph: "\u{F046D}", keys: "picasso ruler measure pixels distance size", sh: "sleep 0.35 && qs ipc call Picasso measure" },
  { name: "New sticky note", glyph: "\uF24A", keys: "clio sticky desktop note", ipc: "Clio add" },
  { name: "Show the shelf", glyph: "\uF01C", keys: "shelf drop drag hold yoink dropover tray", ipc: "Shelf toggle" },
  { name: "New journal entry", glyph: "\u{F0B64}", keys: "clio journal diary write reflect mood", ipc: "Clio journal" },
  { name: "Today's journal entry", glyph: "\u{F00F6}", keys: "clio journal today daily diary", ipc: "Clio today" },
  { name: "Quick note", glyph: "\u{F140B}", keys: "clio capture jot quick note inbox", ipc: "Clio capture" },
  { name: "Tasks", glyph: "\uF14A", keys: "clio todo todos to-do checklist reminders", line: "todos " },
  { name: "Notifications", glyph: "\uF0F3", keys: "howler bell history", ipc: "Howler toggle" },
  { name: "Clear notifications", glyph: "\uF1F6", keys: "howler bell dismiss", ipc: "Howler clear" },
  // `line` is typed into the field rather than run; `inline` is one of
  // Cynosure's own (see CynosurePopup.runInline)
  { name: "Clipboard pictures", glyph: "\uF03E", keys: "folio clipboard images screenshots pics copied", line: "cb pictures" },
  { name: "New script", glyph: "\uF489", keys: "script command raycast shell bash python automate", inline: "newScript" },
  { name: "Scripts directory", glyph: "\uF07C", keys: "scripts commands directory", inline: "scriptsDir" },
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
  { name: "Sound output", glyph: "\u{F04C3}", keys: "zeus speakers headphones audio device sink switch", line: "output " },
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
  { name: "Find a book", glyph: "\uF02D", keys: "minerva books reading pdf epub search", line: "book " },
  // hestia
  { name: "Services", glyph: "\u{F08D6}", keys: "hestia systemd systemctl daemons units", ipc: "Hestia open system" },
  { name: "System journal", glyph: "\u{F09EE}", keys: "hestia logs journalctl errors", ipc: "Hestia journal ''" },
  { name: "What's wrong", glyph: "\u{F05D6}", keys: "hestia failed services errors broken overview health", ipc: "Hestia open overview" },
  // stylus
  { name: "Write an image to a drive", glyph: "\u{F0D13}", keys: "stylus iso usb flash burn etcher rufus sd card bootable dd", ipc: "Stylus open ''" },
  // kairos
  { name: "This week's screen time", glyph: "\u{F0128}", keys: "kairos screen time usage week apps hours", ipc: "Kairos open week" },
  { name: "Cynosure's words", glyph: "\uF059", keys: "help ? commands verbs words scopes cheat sheet cynosure", line: "? " },
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
      glyph: f.glyph, label: f.name, displayText: f.glyph + "  " + f.name, sub: a.sub || "" });
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
// ── SHORT SECTIONS (2026-11-04) ── a section of the whole list shows its
// best three; the rest are a row ("12 more files") that puts the section's
// word in the field as its chip, the line after it. Only sections a chip
// can open; a section one past the cap is shown whole (the row saves none)
const SECTION_CAP = 3;
const MORE_OF = { Files: ["f", "files"], Windows: ["win", "windows"], Clipboard: ["cb", "clips"],
  Snippets: ["cb", "snippets"], Notes: ["notes", "notes"], Settings: ["settings", "settings"] };
function capSections(rows, q, cap) {
  const count = {}, seen = {};
  for (const r of rows) count[r.section] = (count[r.section] || 0) + 1;
  const out = [];
  for (const r of rows) {
    const m = MORE_OF[r.section];
    if (!m || count[r.section] <= cap + 1) { out.push(r); continue; }
    const n = seen[r.section] = (seen[r.section] || 0) + 1;
    if (n > cap) continue;
    out.push(r);
    if (n === cap) {
      const line = m[0] + " " + q;
      out.push({ kind: "more", key: "more:" + r.section, text: line, line,
        label: (count[r.section] - cap) + " more " + m[1], sub: "\u201C" + line + "\u201D", glyph: "\uF141",
        section: r.section });
    }
  }
  return out;
}

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
  if (hay.indexOf(q) >= 0) return 4;
  // looser (2026-11-04), after every plain match, and never for a line you
  // ran (those are what you typed, not names)
  if (r.kind === "hist") return -1;
  return looseRank(String(r.text || ""), q);
}
// first letters ("vsc": Visual Studio Code) 5, the letters in order with
// gaps ("frfx": Firefox) 6, one slip in a word's start ("fierfox") 7
function looseRank(text, q) {
  if (q.length < 2 || /\s/.test(q)) return -1;
  const words = String(text).replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase().split(/[\s\-_.]+/).filter((w) => w !== "");
  if (words.length > 1 && words.map((w) => w[0]).join("").startsWith(q)) return 5;
  if (q.length >= 3) {
    const name = String(text).toLowerCase();
    let at = 0;
    for (const ch of q) { at = name.indexOf(ch, at); if (at < 0) break; at++; }
    if (at > 0 && name[0] === q[0]) return 6;
  }
  if (q.length >= 4)
    for (const w of words)
      for (const n of [q.length - 1, q.length, q.length + 1])
        if (n <= w.length && slips(q, w.slice(0, n)) <= 1) return 7;
  return -1;
}
// how many single letters wrong, missing, extra or swapped: a over b
function slips(a, b) {
  const m = a.length, n = b.length;
  if (Math.abs(m - n) > 1) return 2;
  const d = [];
  for (let i = 0; i <= m; i++) { d.push([i]); for (let j = 1; j <= n; j++) d[i].push(i === 0 ? j : 0); }
  for (let i = 1; i <= m; i++)
    for (let j = 1; j <= n; j++) {
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
    }
  return d[m][n];
}

// `rows` already in frecency order (buildRows); a stable sort on the rank
// keeps that order among equals. `picks` (notePick): what you chose for this
// very line goes first, the most chosen first
// `ranks` (a Map, optional) is given each kept row's rank, for topRows to
// read instead of matching every row a second time
function rankRows(rows, query, picks, ranks) {
  const q = (query || "").trim().toLowerCase();
  if (q === "") return rows.slice();
  const scored = [];
  for (let i = 0; i < rows.length; ++i) {
    const p = pickCount(picks, q, rows[i].key);
    const k = p > 0 ? -2 : matchRank(rows[i], q);
    if (k !== -1) { scored.push({ r: rows[i], k, i, p }); if (ranks) ranks.set(rows[i], k); }
  }
  scored.sort((a, b) => (a.k - b.k) || (b.p - a.p) || (a.i - b.i));
  return scored.map((x) => x.r);
}

function inSection(r, section) {
  return Object.assign({}, r, { section });
}

// ── A WORD MADE A CHIP (2026-11-04, user: "def tab now makes Define a
// chip") ── Tab on a word that narrows the list ("def", "win", "quit")
// takes it out of the line and into the field as a chip: what is typed after
// is only what is looked for. [word, its other spellings, the chip's name]
const CHIPS = [
  ["f", [], "Files"], ["in", [], "Inside files"], ["go", [], "Places"], ["win", [], "Windows"],
  ["cb", [], "Clipboard"], ["notes", [], "Notes"], ["note", [], "New note"], ["todo", [], "New task"],
  ["todos", ["tasks"], "Tasks"], ["books", ["book"], "Books"], ["font", ["fonts"], "Fonts"], ["shots", [], "Screenshots"],
  ["rec", [], "Recordings"], ["colors", [], "Colors you picked"], ["def", ["define"], "Dictionary"],
  ["tr", ["translate"], "Translate"], ["em", ["emoji"], "Emoji"], ["nf", [], "Nerd glyphs"], ["settings", [], "Settings"],
  ["store", ["install"], "Store"], ["pkg", [], "Packages"], ["event", [], "New event"], ["output", [], "Sound output"],
  ["ps", [], "Processes"], ["bt", [], "Bluetooth"], ["wifi", [], "Wi-Fi"], ["repo", [], "Repositories"],
  ["svc", [], "Services"], ["notif", [], "Notifications"], ["help", [], "Help"], ["calc", [], "Calculator"],
  ["bm", [], "Bookmarks"], ["browsed", [], "Browsed"], ["history", [], "History"], ["github", [], "GitHub"], ["prs", [], "Pull requests"],
  ["issues", [], "Issues"], ["music", [], "Music"], ["videos", [], "Videos"], ["menu", [], "Menus"],
  ["contacts", ["contact"], "Contacts"], ["quit", [], "Quit"], ["layout", ["layouts"], "Layouts"], ["snap", ["snaps"], "Snap"],
  ["theme", ["themes"], "Themes"]
];
// the chip a word is: { word (as the line reads it), text }, or null; your
// quick links and scripts that take words are chips too
function chipFor(word, links, scripts) {
  const w = String(word || "").toLowerCase();
  if (w === "") return null;
  for (const c of CHIPS) if (c[0] === w || c[1].indexOf(w) >= 0) return { word: c[0] === "em" && w === "emoji" ? "em" : c[0], text: c[2] };
  const l = (links || []).find((x) => x.word === w);
  if (l) return { word: l.word, text: l.name };
  const sc = (scripts || []).find((x) => x.word === w && x.argument);
  return sc ? { word: sc.word, text: sc.title } : null;
}
// the one chip a start of a word can be ("lay" → layout), or null: two or
// more letters, and only one chip begins so
function chipComplete(prefix, links, scripts) {
  const p = String(prefix || "").toLowerCase();
  if (p.length < 2) return null;
  const found = {};
  for (const c of CHIPS) if (c[0].startsWith(p) || c[1].some((a) => a.startsWith(p))) found[c[0]] = true;
  for (const l of links || []) if (l.word.startsWith(p)) found[l.word] = true;
  for (const sc of scripts || []) if (sc.argument && sc.word.startsWith(p)) found[sc.word] = true;
  const words = Object.keys(found);
  return words.length === 1 ? chipFor(words[0], links, scripts) : null;
}

// ── RELATED CHIPS (2026-11-04) ── with a chip in place, Tab moves it to the
// next of its kin (Windows → Snap → Quit → Layouts → Windows), shift tab
// back; the line after it is kept. A chip in no ring stays as it is; the
// dictionary's and the translator's are in none, their card's tab is its
// recents and languages
const CHIP_RINGS = [["win", "snap", "quit", "layout"], ["f", "in", "go"], ["em", "nf", "font"],
  ["notes", "todos"], ["bm", "browsed"], ["github", "prs", "issues", "repo"],
  ["music", "videos"], ["shots", "rec", "colors"], ["ps", "svc"], ["wifi", "bt", "output"], ["store", "pkg"]];
function chipNext(word, back) {
  const ring = CHIP_RINGS.find((r) => r.indexOf(word) >= 0);
  if (!ring) return null;
  const i = ring.indexOf(word);
  return chipFor(ring[(i + (back ? ring.length - 1 : 1)) % ring.length]);
}

// "snap …": every place the window you were in can go, each one a row
// (2026-11-04, user: "is there any command that lists all available window
// actions"); each also has its words ("left half"), the sub says them
const SNAPS = [
  ["left", "Left half", "left half", "\u{F10AA}"], ["right", "Right half", "right half", "\u{F10AB}"],
  ["top", "Top half", "top half", "\u{F1513}"], ["bottom", "Bottom half", "bottom half", "\u{F10A9}"],
  ["left3", "Left third", "left third", "\u{F056D}"], ["center3", "Center third", "center third", "\u{F056D}"],
  ["right3", "Right third", "right third", "\u{F056D}"], ["left23", "Left two thirds", "left two thirds", "\u{F056D}"],
  ["right23", "Right two thirds", "right two thirds", "\u{F056D}"], ["tl", "Top left quarter", "top left quarter", "\u{F0570}"],
  ["tr", "Top right quarter", "top right quarter", "\u{F0570}"], ["bl", "Bottom left quarter", "bottom left quarter", "\u{F0570}"],
  ["br", "Bottom right quarter", "bottom right quarter", "\u{F0570}"], ["centerHalf", "Center half", "center half", "\uF2D0"],
  ["center", "Center", "center", "\uF0B2"], ["max", "Fill the screen", "maximize", "\u{F0293}"],
  ["almost", "Almost fill the screen", "almost maximize", "\u{F0293}"], ["maxW", "Full width", "maximize width", "\u{F084E}"],
  ["maxH", "Full height", "maximize height", "\u{F084F}"], ["grow", "A tenth larger", "larger", "\u{F004C}"],
  ["shrink", "A tenth smaller", "smaller", "\u{F0044}"], ["next", "To the next screen", "next screen", "\u{F037A}"],
  ["prev", "To the previous screen", "previous screen", "\u{F037A}"], ["restore", "Back where it was", "restore", "\uF0E2"]
];
function snapRows(query, windowName) {
  const q = String(query || "").trim().toLowerCase();
  return SNAPS.filter((x) => q === "" || (x[1] + " " + x[2]).toLowerCase().indexOf(q) >= 0)
    .map((x) => ({ kind: "argcmd", key: "snap:" + x[0], cmd: { kind: "snap", where: x[0] }, text: x[2], label: x[1],
      sub: "\u201C" + x[2] + "\u201D \u00B7 " + (windowName || "the window you were in"), glyph: x[3], section: "Window" }));
}
// "theme …": every theme, as Oracle's Theme list has them (its name with its
// marks, its inks at the right), the worn one ticked (2026-11-07, user).
// `inksOf(option)` is Ora.themeInksFor with Zenon's colors.
function themeRows(options, current, query, inksOf) {
  const q = String(query || "").trim().toLowerCase();
  return (options || []).filter((o) => q === "" || String(o.label).toLowerCase().indexOf(q) >= 0 || String(o.value).indexOf(q) >= 0)
    .map((o) => ({ kind: "argcmd", key: "theme:" + o.value, cmd: { kind: "theme", value: o.value }, text: o.label,
      label: o.label, sub: "", glyph: "", section: "Themes", worn: o.value === current,
      inks: inksOf ? inksOf(o) : null }));
}
// "history …": your searches, newest first (the queries file), to search again
// Each with the chip it was searched under, as the field shows one: a line
// that opens on a chip's word shows that chip and the rest
function searchRows(queries, query, links, scripts) {
  const q = String(query || "").trim().toLowerCase();
  return (queries || []).filter((e) => q === "" || queryText(e).toLowerCase().indexOf(q) >= 0).slice(0, 60)
    .map((e, i) => {
      const line = queryText(e);
      const m = /^\s*(\S+)\s+([\s\S]+)$/.exec(line);
      const c = m ? chipFor(m[1], links, scripts) : null;
      const saved = queryTag(e);
      const tag = c ? { glyph: saved && saved.text === c.text ? saved.glyph : "", text: c.text } : saved;
      return { kind: "search", key: "search:" + i + ":" + line, text: line, label: c ? m[2].trim() : line, sub: "",
        glyph: "\uF1DA", section: "Searches", chipTag: tag };
    });
}
// ── EACH CHIP ITS LAST SEARCHES (2026-11-04) ── a chip with nothing typed
// after it leads with what you last looked for under it ("def" → the words
// you last looked up), from the same searches "history" lists; return
// searches one again
const CHIP_RECENT = 3;
// the chips whose card draws its own recents as chips (Lexi's dictionary
// and translator, Metis' sums): no second list of them under it (user,
// 2026-11-04: "any card that has its own history chips")
const CHIPS_OWN_RECENTS = ["def", "tr", "calc"];
function chipRecentRows(queries, word, links, scripts) {
  const out = [], seen = {};
  if (CHIPS_OWN_RECENTS.indexOf(word) >= 0) return out;
  for (const entry of queries || []) {
    const line = queryText(entry);
    const m = /^\s*(\S+)\s+(.+?)\s*$/.exec(line);
    if (!m) continue;
    const c = chipFor(m[1], links, scripts);
    if (!c || c.word !== word || seen[m[2].toLowerCase()]) continue;
    seen[m[2].toLowerCase()] = true;
    out.push({ kind: "search", key: "recent:" + line, text: c.word + " " + m[2], label: m[2], sub: "",
      glyph: "\uF1DA", section: "Recent" });
    if (out.length >= CHIP_RECENT) break;
  }
  return out;
}
// "quit …": the apps with windows open, one row each, to quit as their
// close buttons would (every window closed); `nameOf(appId)` their names.
// `tray` (bin/trayapps.py: [{ pid, comm, classes }]): an app running in
// the tray with no window open (Steam, user 2026-11-04) is one too, ended
// by its process; one with windows is quit with them, its process too, or
// it would stay on in the tray
function quitRows(wins, query, glyphOf, nameOf, tray) {
  const q = String(query || "").trim().toLowerCase();
  const apps = {};
  const order = [];
  for (const w of wins || []) {
    const app = String(w.app || "");
    if (app === "" || app === "org.quickshell") continue;
    if (!apps[app]) { apps[app] = { app, name: (nameOf ? nameOf(app) : "") || app, titles: [], addresses: [] }; order.push(app); }
    apps[app].titles.push(String(w.title || ""));
    apps[app].addresses.push(w.address);
  }
  const out = [];
  for (const id of order) {
    const a = apps[id];
    if (q !== "" && (a.name + " " + a.app + " " + a.titles.join(" ")).toLowerCase().indexOf(q) < 0) continue;
    const n = a.addresses.length;
    const pids = (tray || []).filter((t) => (t.classes || []).indexOf(id) >= 0).map((t) => t.pid);
    out.push({ kind: "argcmd", key: "quit:" + id, cmd: { kind: "quitApp", app: id, name: a.name, addresses: a.addresses, pids },
      text: a.name, label: "Quit " + a.name, sub: n === 1 ? a.titles[0] : n + " windows",
      glyph: (glyphOf ? glyphOf([id, a.titles[0] || ""]) : "") || "\uF00D", section: "Open apps" });
  }
  for (const t of tray || []) {
    const pid = Number(t.pid) || 0;
    const comm = String(t.comm || "");
    // never the shell itself, nor the session it runs in
    if (pid <= 1 || comm === "" || (t.classes || []).length > 0 || /^(\.?quickshell|qs|hyprland)/i.test(comm)) continue;
    const name = (nameOf ? nameOf(comm) : "") || trayName(comm);
    if (q !== "" && (name + " " + comm).toLowerCase().indexOf(q) < 0) continue;
    out.push({ kind: "argcmd", key: "quitTray:" + pid, cmd: { kind: "quitTray", pid, name }, text: name,
      label: "Quit " + name, sub: "In the tray, no window open",
      glyph: (glyphOf ? glyphOf([comm, name]) : "") || "\uF00D", section: "Open apps" });
  }
  return out;
}
// a process's name said as an app's: "claude-desktop" → "Claude"
function trayName(comm) {
  const w = String(comm || "").replace(/[-_](desktop|bin|app|tray|client)$/i, "").replace(/[-_]+/g, " ").trim();
  return w.charAt(0).toUpperCase() + w.slice(1);
}
// "layout …": the saved layouts to put back, and the line saved as one
// when no layout has that name
function layoutRows(layouts, query) {
  const q = String(query || "").trim();
  const names = Object.keys(layouts || {}).sort();
  const out = [];
  for (const name of names) {
    if (q !== "" && name.toLowerCase().indexOf(q.toLowerCase()) < 0) continue;
    const n = (layouts[name] || []).length;
    out.push({ kind: "argcmd", key: "layout:" + name, cmd: { kind: "layoutUse", name }, text: name,
      label: "Put the windows as \u201C" + name + "\u201D", sub: n + (n === 1 ? " window" : " windows") + "; missing apps are opened",
      glyph: "\uF009", section: "Layouts" });
  }
  if (q === "" && names.length === 0)
    out.push({ kind: "info", key: "layouts:none", text: "", label: "No layouts saved yet",
      sub: "Type a name, then return: where every window is, kept by that name", glyph: "\uF009", section: "Layouts" });
  if (q !== "" && names.indexOf(q) < 0)
    out.push({ kind: "argcmd", key: "layoutSave:" + q, cmd: { kind: "layoutSave", name: q }, text: q,
      label: "Save this layout as \u201C" + q + "\u201D", sub: "Where each window is, on every workspace",
      glyph: "\uF0C7", section: "Layouts" });
  return out;
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
      glyph: glyphOf ? glyphOf({ name, isDir, path: p }) : "" });
  }
  return out;
}

// The Clipboard and Snippets sections, from folio's own lists. `scoped` is
// a "cb …" line: every clip that matches (pictures too, while nothing is
// typed after the word); otherwise the few text clips and snippets that
// match the line, under the others. `stampOf(id)` is folio's "when";
// `thumbOf(id)` its picture, "" until it is made.
// `more` (2026-11-03): { pins: Folio's [{ id, text }], turn: ids marked to
// paste in turn }. "cb links", "cb files", "cb colors", "cb pinned" show
// that kind alone; pins lead the plain "cb". `more.glyphOf` (morpheus'
// glyphFor, handed in) and `more.home` give a path clip its file's glyph
const CLIP_FILTER = [[/^(links?|urls?)$/i, "link"], [/^files?$/i, "file"], [/^colou?rs?$/i, "color"],
  [/^(pinned|pins?)$/i, "pinned"]];
function clipRows(entries, imageIds, snippets, query, scoped, stampOf, thumbOf, perRow, more) {
  let q = String(query || "").trim();
  const pins = (more && more.pins) || [], turn = (more && more.turn) || [];
  const kws = (more && more.keywords) || {};
  const only = scoped ? (CLIP_FILTER.find((f) => f[0].test(q)) || [null, ""])[1] : "";
  if (only !== "") q = "";
  const out = [];
  if (!scoped && q.length < 2) return out;
  // the pictures as a grid: rows of `perRow` thumbnails ("pics"), a cell
  // chosen in the chosen row as an emoji is in its strip
  const per = Math.max(1, perRow || 4);
  const grid = (ids, section) => {
    for (let i = 0; i < ids.length; i += per)
      out.push({ kind: "pics", key: "pics:" + ids[i], section: section || "Pictures", text: "", label: "",
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
  if (scoped && q === "" && only === "") grid((imageIds || []).slice(0, per * 2));
  const pinned = {};
  for (const p of pins) pinned[p.id] = p;
  const byId = {};
  for (const e of entries || []) byId[e.id] = e;
  // a clip that is one file's path wears that file's glyph (Folio.clipPath,
  // 2026-11-05); a pin keeps its pin, plain words the clip
  const glyphOf = more && more.glyphOf, home = (more && more.home) || "";
  const fileGlyph = (e) => {
    const fp = glyphOf ? Folio.clipPath(e.content || e.preview) : null;
    if (!fp) return "";
    const path = home !== "" && /^~(\/|$)/.test(fp.path) ? home + fp.path.slice(1) : fp.path;
    const g = glyphOf({ name: fp.name, isDir: fp.isDir, path });
    // nothing in the map knew it: a copied directory (Terminus copies them
    // without a "/") or a slash-word (/shrug) — the clip glyph says less
    // that is wrong than a page does (audit 11-05)
    return !fp.isDir && g === glyphOf({ name: "\u0001" }) ? "" : g;
  };
  const clip = (e, section) => {
    const line = String(e.preview || "").replace(/\s+/g, " ").trim();
    // a renamed clip is its name, what it holds said after when it came;
    // one marked to paste in turn its place in the turn first
    const when = stampOf ? stampOf(e.id) : "";
    const at = turn.indexOf(e.id);
    const sub = (at >= 0 ? "In turn " + (at + 1) + " \u00B7 " : "")
      + (e.name ? [when, line].filter((x) => x).join(" \u00B7 ") : when);
    return { kind: "clip", key: "clip:" + e.id, id: e.id, text: e.name || line, label: e.name || line,
      name: e.name || "", sub, pinned: !!pinned[e.id], pinText: pinned[e.id] ? pinned[e.id].text : e.content || "",
      gone: !!e.gone, turn: at + 1, glyph: e.gone || pinned[e.id] ? "\uF08D" : fileGlyph(e) || "\uF0EA", section };
  };
  // pins first (on the plain "cb", and as all of "cb pinned"), a pin
  // cliphist has let go from its own words
  if (scoped && (only === "pinned" || (only === "" && q === "")))
    for (const p of pins) {
      const e = byId[p.id] || { id: p.id, preview: p.text, content: p.text, gone: true };
      if (String(e.preview || "") !== "") out.push(clip(e, "Pinned"));
    }
  if (only !== "pinned") {
    const found = Folio.filterEntries(entries || [], q)
      .filter((e) => only === "" ? !(scoped && q === "" && pinned[e.id]) : Folio.clipType(e.content || e.preview) === only);
    for (const e of found.slice(0, 60)) out.push(clip(e, "Clipboard"));
  }
  if (only !== "") return out;
  for (const sn of Folio.snippetRows(snippets || [], q).slice(0, 40))
    out.push({ kind: "snip", key: "snip:" + sn.path, path: sn.path, content: sn.content,
      text: sn.preview, label: sn.preview, keyword: kws[sn.path] || "",
      sub: (kws[sn.path] ? kws[sn.path] + " \u00B7 " : "") + sn.sub, glyph: "\uEB66", section: "Snippets" });
  return out;
}

// The Emoji (or Nerd glyphs) strips, from ideo's sets: `per` cells to a
// row. Any line of two letters or more gets one strip of what matches;
// "em …" / "nf …" (`scoped`) every match, a strip at a time, the whole set
// while nothing is typed after the word (capped: past that, type).
// `recent` (this set's list from parseGlyphs) leads: its own "Recently used"
// strips first, then the rest without them
// `tone`: Oracle's Skin tone, the emoji that have one shown in it
function glyphRows(entries, query, nerd, scoped, per, recent, tone) {
  const q = String(query || "").trim();
  if (!scoped && q.length < 2) return [];
  const n = Math.max(1, per || 14);
  const all = Ideo.filterEntries(entries || [], q);
  const order = {};
  (recent || []).forEach((c, i) => { order[c] = i; });
  const ch = (e) => nerd ? e.char : Ideo.toned(e, tone);
  const used = all.filter((e) => ch(e) in order).sort((a, b) => order[ch(a)] - order[ch(b)])
    .slice(0, scoped ? RECENT_GLYPHS : n);
  // "em …" / "nf …" list the whole set, not its first twelve strips (user,
  // 2026-11-05: "doesn't list all glyphs"); the list is a ListView with
  // reused delegates, so only the strips in view are built. A recent one
  // past the recents' strips is back in its place in the set. On a plain
  // line the one strip of emoji stays.
  const shown = {};
  used.forEach((e) => { shown[ch(e)] = true; });
  const others = all.filter((e) => !(ch(e) in shown));
  const rest = scoped ? others : others.slice(0, Math.max(0, n - used.length));
  const out = [];
  const strips = (list, section, tag) => {
    for (let i = 0; i < list.length; i += n)
      out.push({ kind: "glyphs", key: (nerd ? "nf:" : "em:") + tag + i, nerd: !!nerd, section,
        cells: list.slice(i, i + n).map((e) => ({ char: ch(e), name: e.name || e.cls || "", cls: e.cls || "" })),
        text: "", label: "" });
  };
  strips(used, "Recently used", "r");
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
function topRows(ranked, files, query, freq, fileFreq, picks, ranks) {
  const q = String(query || "").trim().toLowerCase();
  if (q === "") return [];
  const cands = [];
  for (const r of ranked || []) {
    // what you chose for this line before, ahead of all
    const p = pickCount(picks, q, r.key);
    const k = p > 0 ? -2 : ranks && ranks.has(r) ? ranks.get(r) : matchRank(r, q);
    if (k !== -1 && k <= 1) cands.push({ r, k, use: p > 0 ? 1e6 + p : (freq || {})[r.key] || 0 });
  }
  for (const f of files || []) {
    const k = matchRank({ text: f.label, alias: f.alias }, q);
    if (k >= 0 && k <= 1) cands.push({ r: f, k, use: (fileFreq || {})[f.path] || 0 });
  }
  // an alias typed whole is first of all, over a pick too
  for (const c of cands) if (c.r.alias === q) c.k = -3;
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
    const mode = /^(silent|terminal|output|list|inline)$/.test(meta.mode || "") ? meta.mode : "silent";
    out.push({ path, title: meta.title || nice.charAt(0).toUpperCase() + nice.slice(1),
      glyph: meta.glyph || "\uF489", mode, argument: meta.argument || "", refresh: refreshMs(meta.refresh),
      word: (meta.word || stem).toLowerCase().replace(/\s+/g, "-"), keywords: meta.keywords || "" });
  }
  return out;
}
// each script as a command: one that takes words types its word when
// chosen; one that does not runs (CynosurePopup.runInline)
// (a list script types its word, as one that takes words; an inline one
// wears what it last printed, `said`: path → text)
function scriptActions(scripts, said) {
  return (scripts || []).map((sc) => sc.argument || sc.mode === "list"
    ? { name: sc.title, glyph: sc.glyph, keys: sc.word + " " + sc.keywords + " script", line: sc.word + " ", alias: sc.word }
    : { name: sc.title, glyph: sc.glyph, keys: sc.word + " " + sc.keywords + " script", inline: "script", script: sc,
        sub: sc.mode === "inline" ? String((said || {})[sc.path] || "").split("\n")[0].slice(0, 120) : "" });
}
// "wb cairo": the script whose word starts the line, with the words after
function scriptFor(scripts, query) {
  const m = /^\s*(\S+)\s+(.*)$/.exec(String(query || ""));
  if (!m) return null;
  const word = m[1].toLowerCase();
  const sc = (scripts || []).find((x) => x.argument && x.mode !== "list" && x.word === word);
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
    + "# @refresh\n"
    + "# @argument\n"
    + "# @word mine\n"
    + "# @keywords\n"
    + "#\n"
    + "# A Cynosure command. The lines above say how it shows: @mode is silent (in\n"
    + "# the background), terminal (in your terminal) or output (what it prints,\n"
    + "# as a notification), list (what it prints is a list: its @word and a\n"
    + "# space show it, the words after are $1; print JSON objects with title,\n"
    + "# subtitle, glyph, copy, open, paste or run, or plain lines) or inline\n"
    + "# (what it prints is its row's second line; @refresh 30s runs it again\n"
    + "# while the panel is up). Give @argument a few words (\"a city\") and it\n"
    + "# takes what is typed after its @word, as $1.\n"
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
  return out.slice(0, 40);
}

// `extra`: { files: fileRows(…), filesOnly: the line is "f …", fileFreq:
// artemis' frecency for the Top results, clips:
// clipRows(…), clipsOnly: the line is "cb …" }. The calculator is not a
// row: it draws itself over the list (CynosurePopup).
// ── WHAT YOU TOOK OUT OF THE LIST (2026-11-04, Raycast's disabled
// commands) ── Oracle's cynosureHidden: a line an app, command, script or
// quick link, "id<TAB>name"; the id is its kind and key ("app:firefox.desktop").
// A hidden one is gone from the list and its fallbacks, nothing else: its
// word ("lock", "f …") still works when typed in full as a command.
const HIDEABLE = { app: true, shell: true, link: true };
function hideId(r) { return r ? r.kind + ":" + r.key : ""; }
function parseHidden(text) {
  const out = [];
  const seen = {};
  for (const line of String(text || "").split("\n")) {
    const [id, name] = line.split("\t");
    if (!id || seen[id]) continue;
    seen[id] = true;
    out.push({ id, name: name || id.replace(/^[a-z]+:/, "") });
  }
  return out;
}
function hiddenText(list) { return list.map((h) => h.id + "\t" + String(h.name || "").replace(/[\t\n]/g, " ")).join("\n"); }
function withHidden(text, id, name, on) {
  const list = parseHidden(text).filter((h) => h.id !== id);
  if (on) list.push({ id, name });
  return hiddenText(list);
}
function hiddenSet(text) {
  const set = {};
  for (const h of parseHidden(text)) set[h.id] = true;
  return set;
}

// ── THE OTHER WAYS, YOUR ORDER (2026-11-04, Raycast's fallback commands)
// Oracle's cynosureFallbackList: their words in your order, "-" before one
// you turned off ("tr,-pkg,web"); "" is this order, all on. One missing
// from your list (a new one) comes on, at the end.
const FALLBACKS = [
  { word: "web", name: "Search the web", sub: "", glyph: "\uF0AC" },
  { word: "f", name: "Search files", sub: "Artemis", glyph: "\uF002" },
  { word: "cb", name: "Search the clipboard", sub: "Folio", glyph: "\uF0EA" },
  { word: "settings", name: "Search settings", sub: "Oracle", glyph: "\uF013" },
  { word: "store", name: "Search the store", sub: "Ceres", glyph: "\uF07A" },
  { word: "pkg", name: "Search packages", sub: "Ceres", glyph: "\uF187", one: true },
  { word: "notes", name: "Search notes", sub: "Clio", glyph: "NOTE" },
  { word: "note", name: "New note", sub: "Clio", glyph: "NOTE" },
  { word: "event", name: "New event", sub: "Chronos", glyph: "\uF073" },
  { word: "todo", name: "New task", sub: "Clio", glyph: "TASK" },
  { word: "go", name: "Go to a directory", sub: "Terminus", glyph: "\uF07B" },
  { word: "in", name: "Search inside files", sub: "Ripgrep", glyph: "\uF15C", min: 3 },
  { word: "def", name: "Define", sub: "Lexi", glyph: "\uF02D", one: true },
  { word: "tr", name: "Translate", sub: "Lexi", glyph: "\uF1AB" },
  { word: "em", name: "Find emoji", sub: "Ideo", glyph: "\uF118" },
  { word: "run:t", name: "Run in the terminal", sub: "", glyph: "TERM" },
  { word: "run:p", name: "Run in the background", sub: "", glyph: "PROC" }
];
function fallbackList(text) {
  const known = {};
  for (const f of FALLBACKS) known[f.word] = f;
  const out = [];
  const seen = {};
  for (const raw of String(text || "").split(",")) {
    const w = raw.trim();
    const off = w.startsWith("-");
    const word = off ? w.slice(1) : w;
    if (!known[word] || seen[word]) continue;
    seen[word] = true;
    out.push(Object.assign({}, known[word], { on: !off }));
  }
  for (const f of FALLBACKS) if (!seen[f.word]) out.push(Object.assign({}, f, { on: true }));
  return out;
}
// a fallback's glyph, its stand-in words made the real glyph
function fallbackGlyph(g) { return g === "NOTE" ? NOTE_GLYPH : g === "TASK" ? TASK_GLYPH : g === "TERM" ? ICON_T : g === "PROC" ? ICON_P : g; }
function fallbackText(list) { return list.map((f) => (f.on ? "" : "-") + f.word).join(","); }
// one moved by `by` (−1 up, +1 down), or turned on or off
function fallbackMoved(text, word, by) {
  const list = fallbackList(text);
  const i = list.findIndex((f) => f.word === word);
  const j = i + by;
  if (i < 0 || j < 0 || j >= list.length) return fallbackText(list);
  const t = list[i]; list[i] = list[j]; list[j] = t;
  return fallbackText(list);
}
function fallbackSet(text, word, on) {
  return fallbackText(fallbackList(text).map((f) => f.word === word ? Object.assign(f, { on }) : f));
}

function rootRows(rows, query, freq, actions, extra) {
  const q = (query || "").trim();
  const out = [];
  const ex = extra || {};
  // what you took out of the list (Oracle's cynosureHidden)
  if (ex.hidden) rows = rows.filter((r) => !ex.hidden[hideId(r)]);
  if (q === "") {
    // your favorites first, in your order, and not again below
    const taken = {};
    for (const r of ex.favorites || []) { out.push(inSection(r, "Favorites")); taken[r.kind + "\u0000" + r.key] = true; }
    const used = rows.filter((r) => (freq || {})[r.key] > 0 && !taken[r.kind + "\u0000" + r.key])
      .slice(0, ex.suggested === undefined ? SUGGESTED : Math.max(0, ex.suggested));
    for (const r of used) { out.push(inSection(r, "Suggestions")); taken[r.kind + "\u0000" + r.key] = true; }
    for (const kind of ex.history === false ? ["app", "shell"] : ["app", "shell", "hist"])
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
  if (ex.tasksOnly) return (ex.newTask ? [ex.newTask] : []).concat(ex.tasks || []);
  if (ex.booksOnly) return (ex.books || []).slice();
  if (ex.outputsOnly) return (ex.outputs || []).slice();
  if (ex.colorsOnly) return (ex.colors || []).slice();
  if (ex.placesOnly) return (ex.places || []).slice();
  if (ex.procsOnly) return (ex.procs || []).slice();
  if (ex.reposOnly) return (ex.repos || []).slice();
  if (ex.servicesOnly) return (ex.services || []).slice();
  if (ex.notifsOnly) return (ex.notifs || []).slice();
  if (ex.listOnly) return (ex.listItems || []).slice();
  if (ex.hitsOnly) return (ex.hits || []).slice();
  if (ex.fontsOnly) return (ex.fonts || []).slice();
  if (ex.capturesOnly) return (ex.captures || []).slice();
  if (ex.helpOnly) return (ex.help || []).slice();
  // the lookups' words (Lookups.qml: bm, browsed, github, music, menu …)
  if (ex.only) return ex.only.slice();
  // "wifi off" is still the switch, over the networks
  if (ex.radiosOnly) return (ex.command ? [ex.command] : []).concat(ex.radios || []);
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
  const ranks = new Map();
  const ranked = rankRows(rows, q, ex.picks, ranks);
  // the best few of everything named, first; each is then left out of its
  // own section below
  const top = topRows(ranked, files, q, freq, ex.fileFreq, ex.picks, ranks);
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
  if (ex.history !== false)
    for (const r of ranked)
      if (r.kind === "hist" && free(r)) out.push(inSection(r, SECTION_OF.hist));
  // each long section its best few, and a row that opens all of it
  if (!scoped && ex.sectionCap !== false) out.splice(0, out.length, ...capSections(out, q, ex.sectionCap || SECTION_CAP));
  // Offer other ways off (Oracle): what matched, and nothing more
  if (!scoped && ex.fallbacks !== false) {
    const quoted = "\u201C" + q + "\u201D";
    // Raycast's fallbacks: the line handed to each panel that can take it,
    // then run as a command
    const use = "Use " + quoted + " with\u2026";
    const fb = (name, glyph, word, sub) => out.push({ kind: "fallback", key: "fb:" + word, text: q,
      glyph, label: name, sub, action: { line: word + " " + q }, section: use });
    const glyphOf = fallbackGlyph;
    for (const f of fallbackList(ex.fallbackList)) {
      if (!f.on || (f.one && !/^\S+$/.test(q)) || (f.min && q.length < f.min)) continue;
      if (f.word === "web") {
        const web = (ex.links || []).find((l) => l.word === "web");
        if (web && !link && !(ex.hidden && ex.hidden["link:" + web.word]))
          out.push(Object.assign(linkRow(web, q, use), { label: "Search the web", sub: "", fbWord: "web" }));
      } else if (f.word === "run:t" || f.word === "run:p") {
        const t = f.word === "run:t";
        out.push({ kind: "run", key: f.word, mode: t ? "Terminal" : "Process", text: q, glyph: glyphOf(f.glyph),
          label: "Run " + quoted + (t ? " in the terminal" : " in the background"), section: use, fbWord: f.word });
      } else {
        fb(f.name, glyphOf(f.glyph), f.word, f.sub);
        out[out.length - 1].fbWord = f.word;
      }
    }
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
// `r.favorite`: it is one of your favorites (the popup says so); `r.favAt`
// and `r.favCount` where it stands among them, for Move up / Move down
function favActs(r, a) {
  if (!r.favorite) return [a("addFav", "Add to favorites", "\uF005")];
  return [a("dropFav", "Remove from favorites", "\uF006")]
    .concat(r.favAt > 0 ? [a("favUp", "Move up in favorites", "\uF062")] : [])
    .concat(r.favAt < r.favCount - 1 ? [a("favDown", "Move down in favorites", "\uF063")] : []);
}
// right after what return does: a favorite's own actions
function rowActions(r) {
  const out = kindActions(r);
  if (r && HOTKEY_KINDS[r.kind] && out.length > 0)
    out.splice(1, 0, ...favActs(r, (id, text, icon, hint) => ({ id, text, icon, hint: hint || "" })));
  return out;
}
// a fallback's place among them (Oracle's cynosureFallbackList)
function fallbackActs(r, a) {
  if (!r || !r.fbWord) return [];
  return [a("fbUp", "Move up among the other ways", "\uF062"), a("fbDown", "Move down among the other ways", "\uF063"),
    a("fbOff", "Do not offer this", "\uF070")];
}
// out of the list (Oracle's cynosureHidden)
function hideActs(r, a) {
  return r && HIDEABLE[r.kind] ? [a("hide", "Hide from the list", "\uF070")] : [];
}
function kindActions(r) {
  if (!r) return [];
  const a = (id, text, icon, hint) => ({ id, text, icon, hint: hint || "" });
  switch (r.kind) {
  case "app":
    return [a("go", "Open", A_OPEN, "return"), ...aliasActs(r, a), ...hotkeyActs(r, a), a("copyName", "Copy name", A_COPY),
      a("forget", "Forget how often it is used", A_FORGET), ...hideActs(r, a)];
  case "shell":
    return [a("go", r.action && r.action.view ? "Open" : "Run", A_RUN, "return"), ...aliasActs(r, a), ...hotkeyActs(r, a),
      a("copyName", "Copy name", A_COPY), a("forget", "Forget how often it is used", A_FORGET), ...hideActs(r, a)];
  case "hist":
    return [a("go", "Run", A_RUN, "return"), a("runTerminal", "Run in the terminal", "\uEA85"),
      a("runProcess", "Run in the background", "\uEB7F"), ...hotkeyActs(r, a), a("copyName", "Copy command", A_COPY),
      a("forget", "Remove from history", A_FORGET, "delete")];
  case "file":
    return [a("go", r.isDir ? "Open in Terminus" : "Open", A_OPEN, "return"),
      a("reveal", "Show in Terminus", "\uF07C"),
      ...(r.isDir ? [] : [a("openWith", "Open with\u2026", "\uF14C")]),
      ...(r.isDir ? [] : [a("copyFile", "Copy the file", A_COPY)]),
      a("copyPath", "Copy path", A_COPY), a("copyName", "Copy name", A_COPY), ...aliasActs(r, a), ...hotkeyActs(r, a),
      a("trash", "Move to the trash", A_FORGET)];
  case "clip":
    return [a("go", "Copy", A_COPY, "return"),
      ...(/^https?:\/\/\S+$/i.test(String(r.label || "").trim()) ? [a("openUrl", "Open link", A_OPEN)] : []),
      a("keep", "Keep as snippet", "\uEB66", "ctrl s"),
      a("rename", "Rename", "\uF044", "ctrl r"),
      a("pin", r.pinned ? "Unpin" : "Pin to the top", "\uF08D", "ctrl p"),
      ...(r.gone ? [] : [a("turn", r.turn ? "Leave out of the turn" : "Mark to paste in turn", "\uF0CB", "ctrl space")]),
      ...(r.turn ? [a("inTurn", "Paste the marked in turn", "\uF0EA", "ctrl return")] : []),
      ...TRANSFORMS.map((x) => a("as:" + x.id, "Paste as " + x.text, "\uF0EA")),
      a("drop", "Remove from the clipboard", A_FORGET, "delete")];
  case "clipimg": case "pics":
    return [a("go", "Copy", A_COPY, "return"), a("markUp", "Annotate", "\uF040"),
      a("viewPic", "Open in Picasso", "\uF03E"), a("savePic", "Save to Pictures", "\uF0C7"),
      a("drop", "Remove from the clipboard", A_FORGET, "delete")];
  case "snip":
    return [a("go", "Copy", A_COPY, "return"), a("pasteSnip", "Paste", "\uF0EA"), a("edit", "Edit", "\uF040", "ctrl e"),
      a("snipKey", r.keyword ? "Change keyword" : "Set keyword", "\uF11C", "ctrl k"),
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
      ...(r.say ? [a("lexiSay", r.mode === "dict" ? "Say the word" : "Read it out", r.mode === "dict" ? "\u{F07C5}" : "\uF028", "alt p")] : []),
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
  case "newtask":
    return r.bad ? [] : [a("go", r.remind ? "Set the reminder" : "Add the task", r.glyph, "return"),
      a("taskOpen", "Add and open in Clio", A_OPEN)];
  case "task":
    return [a("go", "Mark done", "\uF14A", "return"), a("taskShow", "Open in Clio", A_OPEN), a("copyName", "Copy task", A_COPY)];
  case "book":
    return [a("go", "Read", A_OPEN, "return"), a("reveal", "Show in Terminus", "\uF07C"), a("copyPath", "Copy path", A_COPY),
      a("copyName", "Copy title", A_COPY)];
  case "output":
    return [a("go", "Use for sound", "\u{F04C3}", "return"), a("copyName", "Copy name", A_COPY)];
  case "pcolor":
    // every form it has (Answers.colorForms), the hex first
    return [a("go", "Copy hex", A_COPY, "return"),
      ...(r.forms || []).slice(1).map((f) => a("form:" + f[0], "Copy as " + f[0], A_COPY))];
  case "place":
    return [a("go", r.path === "" ? "Connect and open" : "Open in Terminus", A_OPEN, "return"),
      ...(r.path === "" ? [] : [a("openTerm", "Open a terminal here", "\uEA85"), a("copyPath", "Copy path", A_COPY)]),
      ...(r.uri ? [a("copyUrl", "Copy address", A_COPY)] : [])];
  case "proc":
    return r.pid > 0 ? [a("go", "Quit\u2026", A_FORGET, "return"), a("forceQuit", "Force quit\u2026", A_FORGET),
      a("copyPid", "Copy PID", A_COPY), a("copyName", "Copy command line", A_COPY)] : [];
  case "btdev":
    return [a("go", r.dev.connected ? "Disconnect" : r.dev.paired ? "Connect" : "Pair", "\uF293", "return"),
      a("hermesOpen", "Open in Control Hub", A_OPEN)];
  case "wifinet":
    return [a("go", r.net.connected ? "Leave" : "Join", "\uF1EB", "return"), a("hermesOpen", "Open in Control Hub", A_OPEN)];
  case "repo":
    return [a("go", "Open in Delphi", A_OPEN, "return"), a("reveal", "Show in Terminus", "\uF07C"),
      a("openTerm", "Open a terminal here", "\uEA85"), a("copyPath", "Copy path", A_COPY)];
  case "svc":
    return [a("go", "Open in Hestia", A_OPEN, "return"),
      ...(r.active === "active" ? [a("svcRestart", "Restart", "\uF021"), a("svcStop", "Stop", "\uF04D")]
        : [a("svcStart", "Start", "\uF04B")]),
      a("svcLog", "Show its log", "\u{F09EE}"), a("copyName", "Copy name", A_COPY)];
  case "sitem": {
    const it = r.item;
    const first = it.open ? a("go", "Open", A_OPEN, "return") : it.paste ? a("go", "Paste", "\uF0EA", "return")
      : it.run ? a("go", "Run", A_RUN, "return") : a("go", "Copy", A_COPY, "return");
    return [first].concat(first.text !== "Copy" ? [a("copyItem", "Copy", A_COPY)] : []);
  }
  case "hit":
    return [a("go", "Open in Plato at the line", A_OPEN, "return"), a("reveal", "Show in Terminus", "\uF07C"),
      a("copyLine", "Copy the line", A_COPY), a("copyPath", "Copy path", A_COPY)];
  case "font":
    return [a("go", "Open in Alexandria", A_OPEN, "return"), a("copyName", "Copy family name", A_COPY)];
  case "shot":
    return [a("go", r.video ? "Cut in Argus" : "Open in Picasso", A_OPEN, "return"),
      ...(r.video ? [] : [a("markUp", "Annotate", "\uF040"), a("copyPic", "Copy", A_COPY)]),
      a("copyFile", "Copy the file", A_COPY), a("reveal", "Show in Terminus", "\uF07C"),
      a("copyPath", "Copy path", A_COPY), a("trash", "Move to the trash", A_FORGET)];
  case "help":
    return r.fill ? [a("go", "Type it", "\uF11C", "return")] : [];
  case "notif":
    return [a("go", "Open", A_OPEN, "return"), a("copyName", "Copy title", A_COPY),
      ...(r.body ? [a("copyBody", "Copy text", A_COPY)] : []), a("dropNotif", "Remove from history", A_FORGET, "delete")];
  case "setting":
    return [a("go", "Open in Oracle", A_OPEN, "return"), a("copyName", "Copy name", A_COPY)];
  case "answer":
    return [a("go", "Copy", A_COPY, "return"),
      ...(r.weather ? [a("forecast", "Open the forecast", "\uF073")] : []),
      ...(r.calDay ? [a("calOpen", "Open the calendar", "\uF073")] : []),
      ...(r.kairos ? [a("kairosOpen", "Open screen time", "\u{F0128}")] : [])];
  case "script":
    return [a("go", "Run", A_RUN, "return"), ...hotkeyActs(r, a), a("editScript", "Edit the script", "\uF040"),
      a("copyPath", "Copy its path", A_COPY)];
  case "window":
    return [a("go", "Go to it", A_OPEN, "return"),
      ...(r.here ? [] : [a("winHere", "Move to this workspace", "\uF2D2")]),
      a("winFloat", "Float or tile", "\uF2D0"), a("winCenter", "Center", "\uF0B2"),
      a("winLeft", "Left half", "\u{F10AA}"), a("winRight", "Right half", "\u{F10AB}"),
      a("winMax", "Fill the screen", "\u{F0293}"), a("winNext", "Move to the next screen", "\u{F037A}"),
      a("winFull", "Fullscreen", "\uF065"), a("closeWin", "Close the window", A_FORGET),
      a("copyName", "Copy title", A_COPY)];
  case "argcmd":
    return [a("go", "Do it", A_RUN, "return")];
  case "search":
    return [a("go", "Search again", A_RUN, "return")];
  case "more":
    return [a("go", "Show all", A_RUN, "return")];
  case "web":
    return [a("go", "Open in the browser", A_OPEN, "return"), a("copyUrl", "Copy address", A_COPY)];
  case "contact":
    return [...(r.email ? [a("go", "Write an email", "\uF0E0", "return"), a("copyEmail", "Copy email", A_COPY)] : []),
      ...(r.phone ? [a(r.email ? "copyPhone" : "go", "Copy phone number", A_COPY, r.email ? "" : "return")] : []),
      a("copyName", "Copy name", A_COPY), ...(r.path ? [a("reveal", "Show in Terminus", "\uF07C")] : [])];
  case "traymenu":
    return [a("go", "Choose", A_RUN, "return")];
  case "link":
    // the browsers to always open it in are put in after "go" by the popup
    return [a("go", r.app ? "Open in " + (r.appName || r.app) : "Open in the browser", A_OPEN, "return"), ...hotkeyActs(r, a),
      a("copyUrl", "Copy address", A_COPY), ...fallbackActs(r, a), ...hideActs(r, a),
      ...(r.own && !r.builtin ? [a("dropLink", "Remove quick link", A_FORGET)] : [])];
  case "run": case "fallback": case "scoped":
    return [a("go", r.kind === "run" ? "Run" : "Use", A_RUN, "return"), ...fallbackActs(r, a)];
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
  if (r.kind === "newtask") return r.bad ? "" : r.remind ? "set reminder" : "add task";
  if (r.kind === "task") return "mark done";
  if (r.kind === "book") return "read";
  if (r.kind === "output") return "use";
  if (r.kind === "pcolor") return "copy";
  if (r.kind === "place") return r.path === "" ? "connect" : "open in terminus";
  if (r.kind === "proc") return r.pid > 0 ? "quit" : "";
  if (r.kind === "btdev") return r.dev.connected ? "disconnect" : r.dev.paired ? "connect" : "pair";
  if (r.kind === "wifinet") return r.net.connected ? "leave" : "join";
  if (r.kind === "repo") return "open in delphi";
  if (r.kind === "svc") return "open in hestia";
  if (r.kind === "notif") return "open";
  if (r.kind === "help") return r.fill ? "type it" : "";
  if (r.kind === "sitem") return r.item.open ? "open" : r.item.paste ? "paste" : r.item.run ? "run" : "copy";
  if (r.kind === "hit") return "open in plato";
  if (r.kind === "font" || r.kind === "fonts") return "open in alexandria";
  if (r.kind === "shots") return "open";
  if (r.kind === "newevent") return r.bad ? "" : "add to calendar";
  if (r.kind === "storeapp") return "open in ceres";
  if (r.kind === "fallback") return "use";
  if (r.kind === "link" || r.kind === "web") return "open";
  if (r.kind === "traymenu") return "choose";
  if (r.kind === "contact") return r.email ? "email" : r.phone ? "copy number" : "copy";
  if (r.kind === "info") return "";
  if (r.kind === "argcmd") return "do it";
  if (r.kind === "search") return "search again";
  if (r.kind === "more") return "show all";
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
  if (r.kind === "web") return "Page";
  if (r.kind === "traymenu") return "Menu item";
  if (r.kind === "contact") return "Contact";
  if (r.kind === "info") return "";
  if (r.kind === "argcmd") return r.cmd && r.cmd.kind === "theme" ? "Theme" : "Command";
  if (r.kind === "search") return "Search";
  if (r.kind === "window") return r.focused ? "This window" : "Window";
  if (r.kind === "script") return "Script";
  if (r.kind === "setting") return "Setting";
  if (r.kind === "note") return r.entry ? "Journal entry" : "Note";
  if (r.kind === "package") return r.installed ? "Installed" : r.aur ? "AUR package" : "Package";
  if (r.kind === "newnote") return "Command";
  if (r.kind === "newtask") return r.bad ? "" : r.remind ? "Reminder" : "New task";
  if (r.kind === "task") return "Task";
  if (r.kind === "book") return ({ pdf: "PDF", epub: "EPUB", comic: "Comic", text: "Text" })[r.book.kind] || "Book";
  if (r.kind === "output") return "Output";
  if (r.kind === "pcolor") return "Color";
  if (r.kind === "place") return r.uri ? "Network place" : "Directory";
  if (r.kind === "proc") return "Process";
  if (r.kind === "btdev") return "Device";
  if (r.kind === "wifinet") return "Network";
  if (r.kind === "repo") return "Repository";
  if (r.kind === "svc") return "Service";
  if (r.kind === "notif") return "Notification";
  if (r.kind === "help") return "";
  if (r.kind === "sitem") return "Script";
  if (r.kind === "hit") return "Line";
  if (r.kind === "font") return "Font";
  if (r.kind === "fonts") return "";
  if (r.kind === "shots") return "";
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
