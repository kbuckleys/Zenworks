.pragma library
// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SUITE'S OWN APPS (2026-11-04), as something to choose: none of them
// has a desktop entry, so a list of installed apps never shows them. Each
// opens by its ipc call (the same ones morpheus/py/apprestore.py keeps in
// ZEN). Chosen ones are kept as "zen:<id>", which no desktop entry's id can
// be. Hot corners' "Open an app" lists them above the installed ones.

const APPS = [
  { id: "alexandria", name: "Alexandria", call: ["Alexandria", "open", ""] },
  { id: "argus", name: "Argus", call: ["Argus", "last"] },
  { id: "calypso", name: "Calypso", call: ["Calypso", "open"] },
  { id: "ceres", name: "Ceres", call: ["Ceres", "window", "store"] },
  { id: "chronos", name: "Chronos", call: ["Calendar", "open", ""] },
  { id: "clio", name: "Clio", call: ["Clio", "open"] },
  { id: "hermes", name: "Control Hub", call: ["Hermes", "window", ""] },
  { id: "cynosure", name: "Cynosure", call: ["Cynosure", "toggle"] },
  { id: "delphi", name: "Delphi", call: ["Delphi", "open", ""] },
  { id: "hestia", name: "Hestia", call: ["Hestia", "open", ""] },
  { id: "kairos", name: "Kairos", call: ["Kairos", "open", ""] },
  { id: "minerva", name: "Minerva", call: ["Minerva", "open", ""] },
  { id: "oracle", name: "Oracle", call: ["Oracle", "open"] },
  { id: "picasso", name: "Picasso", call: ["Picasso", "toggle"] },
  { id: "plato", name: "Plato", call: ["Plato", "open", ""] },
  { id: "stylus", name: "Stylus", call: ["Stylus", "open", ""] },
  { id: "terminus", name: "Terminus", call: ["Terminus", "spawn", ""] }
];

const PREFIX = "zen:";
// U+F2D0, a window: the glyph of an app no map knows
const WINDOW = "\uF2D0";

// the desktop entries that ARE the suite's apps (most have one; Picasso's
// is picasso-view): a list of installed apps leaves them out, the suite's
// own rows already standing for them
function entryIds() { return APPS.map((a) => a.id).concat(["picasso-view"]); }

function isSuite(id) { return String(id || "").startsWith(PREFIX); }

function find(id) {
  const bare = String(id || "").slice(PREFIX.length);
  return APPS.find((a) => a.id === bare) || null;
}

// rows for a picker: { id: "zen:…", name, glyph }, glyphOf(id) the app glyph
function rows(glyphOf) {
  return APPS.map((a) => ({ id: PREFIX + a.id, name: a.name,
                           glyph: (glyphOf ? glyphOf([a.id, a.name]) : "") || WINDOW }));
}

// the command that opens a "zen:" choice, or [] for one this list lacks
function command(id) {
  const a = find(id);
  return a ? ["qs", "ipc", "call"].concat(a.call) : [];
}

// a choice's name: the suite's own, or nameOfEntry(id) for an installed app
function nameOf(id, nameOfEntry) {
  if (isSuite(id)) { const a = find(id); return a ? a.name : ""; }
  return nameOfEntry ? nameOfEntry(id) : String(id || "");
}
