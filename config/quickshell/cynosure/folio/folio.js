// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

.pragma library
.import qs.morpheus as Morpheus
// ONE COPY FOR THE WHOLE SHELL. Without the pragma every component instance
// that imports this file evaluated all of it again (see morpheus/icons.js).
// The shell's singletons come in through the imports above (the same
// instances); the node tests hand in stubs of their own.
var Paths = typeof Morpheus !== "undefined" ? Morpheus.Paths : globalThis.Paths;
var UserDirs = typeof Morpheus !== "undefined" ? Morpheus.UserDirs : globalThis.UserDirs;
var Strings = typeof Morpheus !== "undefined" ? Morpheus.Strings : globalThis.Strings;

function thumbDir() {
  return Paths.cacheDir() + "/cliphist";
}

// Where a clipboard image is decoded to be opened or dragged. The RUNTIME
// directory, not /tmp: a predictable name in a shared, sticky /tmp could be
// made first by another user — to read the images, or as a symlink for the
// `>` redirect to write through.
function openDir() {
  return Paths.runtimeDir() + "/cliphist-open";
}

const THUMB = 256;

// `ink`: the match's color, a 6-digit hex (Zenon.hex) — the theme's, so
// it follows a theme change
function highlightedPreview(text, query, ink) {
  const q = (query || "").trim().toLowerCase();
  if (!q) return Strings.escapeHtml(text);
  const lower = text.toLowerCase();
  const out = [];
  let i = 0;
  while (i < text.length) {
    const idx = lower.indexOf(q, i);
    if (idx < 0) {
      out.push(Strings.escapeHtml(text.slice(i)));
      break;
    }
    if (idx > i) out.push(Strings.escapeHtml(text.slice(i, idx)));
    out.push("<span style=\"color:" + ink + ";font-weight:700;\">" + Strings.escapeHtml(text.slice(idx, idx + q.length)) + "</span>");
    i = idx + q.length;
  }
  return out.join("");
}

function cleanText(s) {
  s = String(s || "");
  s = s.replace(/\r/g, "");
  s = s.replace(/\0/g, "");
  s = s.replace(/\u001f/g, "");
  s = s.replace(/\n/g, " \u21b5 ");
  s = s.replace(/\s+/g, " ");
  return s;
}

function preview(s) {
  let p = cleanText(s);
  if (p === "") p = "(empty)";
  return p;
}

function parseList(text) {
  const entries = [];
  const imageIds = [];
  if (!text) return { entries: entries, imageIds: imageIds };
  for (const line of text.split("\n")) {
    if (line.trim() === "") continue;
    const m = line.match(/^(\d+)\t(.*)$/);
    if (!m) continue;
    const id = m[1];
    const content = m[2];
    if (content.startsWith("[[ binary")) {
      imageIds.push(id);
    } else {
      entries.push({ id: id, content: content, preview: preview(content) });
    }
  }
  return { entries: entries, imageIds: imageIds };
}

function filterEntries(entries, query) {
  const q = (query || "").trim().toLowerCase();
  if (q === "") return entries.slice();
  const out = [];
  for (const e of entries) {
    if ((e.content + " " + e.preview + " " + (e.name || "")).toLowerCase().includes(q)) out.push(e);
  }
  return out;
}

// ── NAMES (2026-11-03) ───────────────────────────────────────────────────
// A clip renamed (Cynosure's "Rename"): id → name, beside the ledger. The
// name is shown and found in the entry's place; an empty one takes it away.
function namesPath() {
  return thumbDir() + "/folio-names.json";
}
function withNames(entries, names) {
  const n = names || {};
  return (entries || []).map((e) => n[e.id] ? Object.assign({}, e, { name: n[e.id] }) : e);
}
function setName(names, id, name) {
  const out = Object.assign({}, names || {});
  const t = String(name || "").replace(/\s+/g, " ").trim();
  if (t === "") delete out[id]; else out[id] = t;
  return out;
}

// ── PINS (2026-11-03) ────────────────────────────────────────────────────
// Clips kept at the top of "cb", in the order pinned: [{ id, text }]. The
// text is kept too, so a pin outlives cliphist letting its entry go (a
// picture's is "" and goes with it).
function pinsPath() {
  return thumbDir() + "/folio-pins.json";
}
function parsePins(text) {
  try { const j = JSON.parse(String(text || "")); return Array.isArray(j) ? j.filter((p) => p && p.id) : []; }
  catch (e) { return []; }
}
function togglePin(pins, id, text) {
  const list = (pins || []).slice();
  const i = list.findIndex((p) => p.id === id);
  if (i >= 0) list.splice(i, 1); else list.push({ id, text: String(text || "") });
  return list;
}
// what a clip is, for "cb links", "cb files", "cb colors"
function clipType(text) {
  const t = String(text || "").trim();
  if (/^https?:\/\/\S+$/i.test(t) || /^www\.\S+\.\S+$/i.test(t)) return "link";
  if (/^(file:\/\/|~?\/)\S/.test(t) && t.split("\n").every((l) => /^(file:\/\/|~?\/)\S*$/.test(l.trim()))) return "file";
  if (/^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t) || /^(rgba?|hsla?|oklch)\([^)]*\)$/i.test(t)) return "color";
  return "text";
}

// A clip that is ONE file's path (2026-11-05): { path, name, isDir }, or
// null. Its row wears that file's glyph from morpheus' map (glyphFor), as
// Terminus shows it, not the generic clip one (user: "these generic glyphs
// can be misleading"). An absolute path, ~/…, or a file:// URI (decoded);
// a trailing / is a directory. Several paths, plain words, or cliphist's
// cut preview (…) are not one file. cliphist folds lines into spaces, so a
// space before another path start is several paths; a space inside one
// counts only when the name ends in an extension or the path in "/" —
// "/usr/bin is great" is words. `path` is without its trailing /, as
// Terminus keys a directory.
function clipPath(text) {
  let t = String(text || "").trim();
  if (t === "" || t.length > 4096 || /[\n\r\0]|↵|…$/.test(t)) return null;
  const uri = /^file:\/\//i.test(t);
  if (uri) {
    t = t.replace(/^file:\/\/(localhost)?/i, "");
    try { t = decodeURIComponent(t); } catch (e) { return null; }
  }
  if (!/^(~?\/)/.test(t) || /\s(file:\/\/|~?\/)/i.test(t)) return null;
  const isDir = t.length > 1 && /\/$/.test(t) || t === "/" || t === "~/";
  const bare = t.replace(/(.)\/+$/, "$1");
  const name = baseName(bare) || bare;
  // a URI's spaces were %20: no word/path doubt there (audit 11-05)
  if (!uri && /\s/.test(bare) && !isDir && !/\.[A-Za-z0-9]{1,8}$/.test(name)) return null;
  return { path: bare, name, isDir };
}

// ── IN TURN (2026-11-03) ─────────────────────────────────────────────────
// Clips pasted one after another: each put on the clipboard for one paste
// (wl-copy --paste-once), the next once that one is taken. cliphist's text
// watcher would take it first, so it is stopped for the run and started
// again after (and on any end: the trap). A new run ends the one before.
function inTurnCommand(ids, runDir) {
  // the watcher's words never appear whole in this script, or pkill -f
  // and pgrep -f would find the script itself ("tex""t" joins to text)
  return "P=" + Strings.shellQuote(runDir + "/folio-inturn.pid") + "; W='wl-paste --type tex''t --watch cliphist store'\n"
    + "[ -f \"$P\" ] && kill \"$(cat \"$P\")\" 2>/dev/null; echo $$ > \"$P\"\n"
    + "pkill -f \"$W\"\n"
    // only the run still named in the pid file gives the watcher back: an
    // older one ends late, once its wl-copy loses the clipboard
    + "trap '[ \"$(cat \"$P\" 2>/dev/null)\" = \"$$\" ] && { rm -f \"$P\"; pgrep -f \"$W\" >/dev/null || setsid -f $W; }' EXIT\n"
    + "trap 'exit 0' TERM INT\n"
    + "n=0; for id in " + ids.map((i) => Strings.shellQuote(i)).join(" ") + "; do n=$((n+1))\n"
    + "  printf '%s' \"$id\" | cliphist decode | timeout 600 wl-copy --paste-once --foreground || exit 0\n"
    + "done\nnotify-send -a folio -- 'Pasted in turn' \"$n clips, one after another\"\n";
}

function thumbCommand(ids, dir) {
  if (!ids || ids.length === 0) return null;
  const quoted = ids.map((i) => Strings.shellQuote(i)).join(" ");
  // The directory reaches the inner script as $1, not spliced into its
  // single-quoted text, where a quote in $XDG_CACHE_HOME would end it.
  return "mkdir -p " + Strings.shellQuote(dir) + "; printf '%s\\n' " + quoted +
      " | xargs -P 8 -I{} sh -c '[ -f \"$1/{}.png\" ] || { printf \"%s\" \"{}\" | cliphist decode | " +
      "magick - -thumbnail " + THUMB + "x" + THUMB + " -background none -gravity center -extent " +
      THUMB + "x" + THUMB + " \"$1/{}.png\" >/dev/null 2>&1; }' folio-thumb " + Strings.shellQuote(dir);
}

function copyCommand(id) {
  return "printf '%s' " + Strings.shellQuote(id) + " | cliphist decode | wl-copy";
}

function deleteCommand(id, dir) {
  return "printf '%s' " + Strings.shellQuote(id) + " | cliphist delete; rm -f " +
      Strings.shellQuote(dir + "/" + id + ".png");
}

// The preview is rich text — it is drawn with Text.RichText so a match can be
// marked — and a drag card is a plain label. Tags stripped and entities put
// back, then trimmed to something that reads at a glance beside a moving
// cursor rather than a paragraph trailing off the screen.
function plain(s) {
  var t = String(s || "").replace(/<[^>]*>/g, "");
  t = t.replace(/&lt;/g, "<").replace(/&gt;/g, ">")
       .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
       .replace(/&amp;/g, "&");
  t = t.replace(/\s+/g, " ").trim();
  return t.length > 48 ? t.slice(0, 47) + "\u2026" : t;
}

// The file's own name, for the same card.
function baseName(p) {
  var s = String(p || "");
  var cut = s.lastIndexOf("/");
  return cut < 0 ? s : s.slice(cut + 1);
}

// THE FULL IMAGE, WRITTEN OUT SO IT CAN BE DRAGGED SOMEWHERE.
//
// The grid draws thumbnails — small PNGs this module renders for itself — and
// handing one of those to another application would be giving it a downscaled
// copy of what it asked for. cliphist still holds the original, so a drag
// decodes the original, and prints where it landed. Shift+return uses the
// same file to hand the image to the annotator.
//
// A half-hour sweep of the same directory on every write: a dragged image
// is a file somebody else now owns a copy of, and leaving ours behind forever
// would make a cache out of every drag.
function dragFileCommand(id, dir) {
  const file = dir + "/" + id + ".png";
  return "mkdir -p -m 700 " + Strings.shellQuote(dir) + "; find " + Strings.shellQuote(dir) +
      " -type f -name '*.png' -mmin +30 -delete 2>/dev/null; printf '%s' " +
      Strings.shellQuote(id) + " | cliphist decode > " + Strings.shellQuote(file) +
      "; [ -s " + Strings.shellQuote(file) + " ] && printf '%s' " +
      Strings.shellQuote(file);
}

// ── WHEN EACH ENTRY ARRIVED ─────────────────────────────────────────────
// cliphist keeps no time at all: its database is id → bytes and nothing
// else. So folio keeps its own ledger beside it, id → milliseconds, filled
// in by watching the database for the one CLOSE_WRITE each `cliphist store`
// makes (a list or a decode makes none, so reading it back cannot loop).
//
// An id the ledger has never seen gets `now` when the scan was set off by a
// store, and 0 — "no time known" — when it was the scan the shell does on
// starting, because those arrived while nobody was watching and stamping
// them with the start time would be a confident lie. The very first run has
// no ledger, so everything already there is 0 the same way.
//
// `carry` is a re-copy from folio itself: cliphist dedupes by deleting the
// old entry and storing it again under a new id, and the moment it was
// first taken belongs to the new id rather than being reset to now.
function ledgerPath() {
  return thumbDir() + "/folio-ledger.json";
}

function parseLedger(text) {
  try {
    const o = JSON.parse(text || "");
    return o && typeof o === "object" ? o : null;
  } catch (e) {
    return null;
  }
}

function listIds(text) {
  const ids = [];
  for (const line of String(text || "").split("\n")) {
    const m = line.match(/^(\d+)\t/);
    if (m) ids.push(m[1]);
  }
  return ids;
}

// ids are newest first, as cliphist lists them. Returns the new ledger, or
// null when nothing changed and there is nothing to write.
function reconcile(ledger, ids, live, now, carry) {
  const out = {};
  let changed = false;
  let carried = false;
  for (const id of ids) {
    if (ledger[id] !== undefined) { out[id] = ledger[id]; continue; }
    changed = true;
    if (!live) { out[id] = 0; continue; }
    // only the newest unseen id can be the re-copy
    if (carry !== null && carry !== undefined && !carried) { out[id] = carry; carried = true; }
    else out[id] = now;
  }
  for (const id in ledger) if (out[id] === undefined) { changed = true; break; }
  return changed ? out : null;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// "Today · 14:32", "Yesterday · 9:05 PM", "Oct 3 · 14:32", and the year only
// when it is not this one. Both halves always: what this row is for is when
// you copied it, and "3d ago" answers only half of that.
function stampLabel(ms, now, h24) {
  if (!ms) return "Time unknown";
  const d = new Date(ms);
  const n = new Date(now);
  const mins = String(d.getMinutes()).padStart(2, "0");
  const time = h24
    ? String(d.getHours()).padStart(2, "0") + ":" + mins
    : ((d.getHours() + 11) % 12 + 1) + ":" + mins + (d.getHours() < 12 ? " AM" : " PM");
  const day0 = new Date(n.getFullYear(), n.getMonth(), n.getDate()).getTime();
  const then0 = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const back = Math.round((day0 - then0) / 86400000);
  let day;
  if (back === 0) day = "Today";
  else if (back === 1) day = "Yesterday";
  else {
    day = MONTHS[d.getMonth()] + " " + d.getDate();
    if (d.getFullYear() !== n.getFullYear()) day += " " + d.getFullYear();
  }
  return day + " · " + time;
}

// PAIRS, NOT MARKUP. It used to hand back finished rich text with the colors
// written into it as hex — which meant the palette lived in two places, and a
// hint could only ever be drawn one way. The popup draws these as chips now;
// what belongs here is which key and what it does.
function hintText(mode) {
  const tab = ["tab", "next mode"];
  const del = ["delete", "remove entry"];
  const open = ["shift return", "annotate"];
  if (mode === "image") return [tab, open, del];
  if (mode === "snip") return [tab, ["return", "paste"], ["ctrl n", "new"], ["ctrl e", "edit"], ["delete", "remove"]];
  if (mode === "edit") return [["ctrl s", "save"], ["esc", "cancel"]];
  return [tab, ["ctrl s", "keep as snippet"], del];
}

// ── SNIPPETS (2026-10-21) ────────────────────────────────────────────────
// Text you paste again and again, kept: one plain .txt file each in the
// snippets directory, named by its file name. Folio's third mode lists them;
// return pastes one with its placeholders filled in, and ctrl n / ctrl e turn
// the panel itself into the page they are written on (a sticky's, plain).
//
//   {date} 2026-10-21   {time} 14:05   {datetime} 2026-10-21 14:05
//   {weekday} Tuesday   {year} {month} {day}   {clipboard} what was copied
//   last — and {{ }} for a literal brace
// ~/Documents/Snippets (user, 2026-10-21): something you wrote, kept where
// your documents are. The old place is emptied into it on the first listing.
function snippetDir() {
  return UserDirs.documents + "/Snippets";
}
function oldSnippetDir() {
  return Paths.dataDir() + "/folio/snippets";
}
// a name as typed, made safe as a file name; "" when nothing is left
function snippetFileName(name) {
  return String(name || "").replace(/[\/\\:*?"<>|\n\r\t]/g, "").trim().slice(0, 80);
}
// the listing command's JSON: [{ name, path, text }]
function parseSnippets(text) {
  let j;
  try { j = JSON.parse(String(text || "")); } catch (e) { return []; }
  if (!Array.isArray(j)) return [];
  return j.filter((s) => s && s.name && s.path).map((s) => ({
    name: String(s.name), path: String(s.path), text: String(s.text || "")
  })).sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
}
// the rows the text pane draws: the name, and the text under it
function snippetRows(snips, query) {
  const q = String(query || "").trim().toLowerCase();
  return (snips || []).filter((s) => q === "" || (s.name + " " + s.text).toLowerCase().includes(q))
    .map((s) => ({ id: "snip:" + s.name, snip: true, path: s.path, content: s.text,
                   preview: s.name, sub: preview(s.text) }));
}
const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
// A snippet's placeholders, filled as it goes out:
//   {date} {time} {datetime} {weekday} {year} {month} {day} {clipboard}
//   {date +3d} {weekday -1d} {datetime +2h} …  — offset by s m h d w or M
//     (months), for any of the date ones (user, 2026-11-01: Raycast's)
//   {uuid}                                     — a new one each time
//   {cursor}                                   — where the caret lands, pasted
// {{ and }} are literal braces. An unknown one is left as it is.
function shiftDate(d, n, unit) {
  const x = new Date(d.getTime());
  if (unit === "M") x.setMonth(x.getMonth() + n);
  else x.setTime(x.getTime() + n * ({ s: 1e3, m: 6e4, h: 36e5, d: 864e5, w: 6048e5 }[unit] || 0));
  return x;
}
function newUuid() {
  let s = "";
  for (let i = 0; i < 32; i++) s += Math.floor(Math.random() * 16).toString(16);
  return s.slice(0, 8) + "-" + s.slice(8, 12) + "-4" + s.slice(13, 16) + "-"
    + "89ab"[Math.floor(Math.random() * 4)] + s.slice(17, 20) + "-" + s.slice(20, 32);
}
// → { text, back }: `back` is how many characters follow {cursor} (0 with none)
function expandSnippetAt(text, now, clipboard) {
  const base = now || new Date();
  const two = (n) => (n < 10 ? "0" : "") + n;
  const vals = (d) => {
    const date = d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate());
    const time = two(d.getHours()) + ":" + two(d.getMinutes());
    return { date: date, time: time, datetime: date + " " + time, weekday: WEEKDAYS[d.getDay()],
             year: String(d.getFullYear()), month: two(d.getMonth() + 1), day: two(d.getDate()) };
  };
  const out = String(text || "")
    .replace(/\{\{/g, "\u0001").replace(/\}\}/g, "\u0002")
    .replace(/\{([a-z]+)(?:\s*([+-])\s*(\d+)\s*([smhdwM]))?\}/g, (m, k, sign, n, unit) => {
      if (k === "clipboard" && !sign) return String(clipboard || "");
      if (k === "uuid" && !sign) return newUuid();
      if (k === "cursor" && !sign) return "\u0003";
      const d = sign ? shiftDate(base, (sign === "-" ? -1 : 1) * Number(n), unit) : base;
      const v = vals(d)[k];
      return v !== undefined ? v : m;
    })
    .replace(/\u0001/g, "{").replace(/\u0002/g, "}");
  const at = out.indexOf("\u0003");
  const clean = out.replace(/\u0003/g, "");
  return { text: clean, back: at < 0 ? 0 : Array.from(clean.slice(at)).length };
}
// ── VALUES ASKED FOR (2026-11-04, Raycast's {argument}) ──────────────────
// {argument name="client"} (or {argument name="client" default="Acme"},
// or a bare {argument}) is asked for in Cynosure before the snippet is
// copied, pasted or typed; the same name twice is asked once. [{ name, def }]
const ARG_RE = /\{argument(?:\s+name\s*=\s*"([^"]*)")?(?:\s+default\s*=\s*"([^"]*)")?\s*\}/g;
function snippetArgs(text) {
  const out = [];
  const seen = {};
  const t = String(text || "").replace(/\{\{|\}\}/g, "  ");
  let m;
  ARG_RE.lastIndex = 0;
  while ((m = ARG_RE.exec(t)) !== null) {
    const name = (m[1] || "").trim() || "Value";
    if (seen[name]) continue;
    seen[name] = true;
    out.push({ name, def: m[2] || "" });
  }
  return out;
}
// the snippet with what was given in its {argument}s, braces in an answer
// kept as typed (not read as {date} and the rest)
function fillArgs(text, values) {
  const v = values || {};
  const esc = (s) => String(s).replace(/\{/g, "{{").replace(/\}/g, "}}");
  return String(text || "").replace(ARG_RE, (m, name, def) => {
    const k = (name || "").trim() || "Value";
    return esc(k in v ? v[k] : def || "");
  });
}
function expandSnippet(text, now, clipboard) {
  return expandSnippetAt(text, now, clipboard).text;
}
// the keys that put the snippet where it was asked for: typed (wtype), then
// the caret walked back to {cursor}; on the clipboard too
function pasteSnippetCommand(text, back) {
  const q = "'" + String(text).replace(/'/g, "'\\''") + "'";
  return "sleep 0.3 && printf '%s' " + q + " | wl-copy >/dev/null 2>&1; wtype -- " + q
    + (back > 0 ? " && for _ in $(seq " + Math.min(5000, back) + "); do wtype -k Left; done" : "");
}
// ── KEYWORDS (2026-11-03) ─────────────────────────────────────────────────
// What you type anywhere for a snippet (Cynosure's expand.py): keyword →
// the snippet's file, beside the ledger.
function keywordsPath() {
  return thumbDir() + "/folio-keywords.json";
}
function parseKeywords(text) {
  let j;
  try { j = JSON.parse(String(text || "")); } catch (e) { return {}; }
  const out = {};
  for (const k in j || {}) if (typeof j[k] === "string" && /^\S{2,32}$/.test(k)) out[k] = j[k];
  return out;
}
function keywordsByPath(keys) {
  const out = {};
  for (const k in keys || {}) out[keys[k]] = k;
  return out;
}
// the keyword set for the snippet at `path` (its old one let go): { keys }
// or { problem }. Empty takes it away. Two letters at least, no spaces;
// one another snippet had is moved here.
function setKeyword(keys, word, path) {
  const w = String(word || "").trim();
  const out = {};
  for (const k in keys || {}) if (keys[k] !== path && k !== w) out[k] = keys[k];
  if (w === "") return { keys: out };
  if (/\s/.test(w)) return { problem: "One word, no spaces" };
  if (Array.from(w).length < 2) return { problem: "Two characters at least" };
  if (Array.from(w).length > 32) return { problem: "32 characters at most" };
  out[w] = path;
  return { keys: out };
}
// the keys that put a snippet in a keyword's place: the keyword erased
// (`erase` characters), the text typed, the caret walked back to {cursor}
// — wtype's, each its own run, in order
function expandKeys(erase, text, back) {
  const out = [];
  if (erase > 0) out.push(["wtype"].concat([].concat(...Array(Math.min(64, erase)).fill(["-k", "BackSpace"]))));
  if (String(text) !== "") out.push(["wtype", "--", String(text)]);
  if (back > 0) out.push(["wtype"].concat([].concat(...Array(Math.min(5000, back)).fill(["-k", "Left"]))));
  return out;
}

// a name for a clip kept as a snippet: its first few words, safe as a file
// name, and not one already taken ("…", "… 2", "… 3")
function snippetName(text, taken) {
  let base = cleanText(text).split(/\s+/).filter((w) => w !== "").slice(0, 5).join(" ")
    .replace(/[\/\\:*?"<>|]/g, "").slice(0, 48).trim();
  if (base === "") base = "Snippet";
  const used = {};
  (taken || []).forEach((n) => used[n.toLowerCase()] = true);
  let name = base;
  for (let i = 2; used[name.toLowerCase()] && i < 1000; ++i) name = base + " " + i;
  return name;
}
