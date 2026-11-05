// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE KEY IS CALLED RETURN (user, 2026-11-03). Every key people read —
// a hint row's ["return", "open"], a menu row's hint:/mark:, a KeyCap, a
// "· return keeps it" in a line of help — names it "return" (Return,
// shift+return…, in each place's own case). What it catches: a quoted
// string that IS a key name ending in enter ("enter", "alt enter",
// "Ctrl+Enter"), a "· enter" inside a help line, and "Enter to …" in a
// message. What it leaves alone: Qt.Key_Enter, KP_Enter, <Enter> and the
// verb ("Enter the Clio password").

"use strict";

const fs = require("fs");
const path = require("path");

const SKIP_DIR = /^(oracle\/tests|oracle\/qmltests|themes)(\/|$)/;
const MODS = "(?:(?:ctrl|control|shift|alt|super|meta|cmd|mod|⇧|⌃|⌥)[ +\\-]?)*";
const BAD = [
  // (an animation's property: "enter" is a property named enter)
  new RegExp("(?<!property:\\s*)([\"'`])" + MODS + "enter\\1", "i"),
  new RegExp("(?:·|\\\\u00b7)\\s+" + MODS + "enter\\b", "i"),
  /\bEnter to \w/,
];

function walk(root, d, out) {
  for (const e of fs.readdirSync(path.join(root, d), { withFileTypes: true })) {
    const rel = d ? d + "/" + e.name : e.name;
    if (e.name.startsWith(".") || SKIP_DIR.test(rel)) continue;
    if (e.isDirectory()) walk(root, rel, out);
    else if (/\.(qml|js|py|lua)$/.test(e.name)) out.push(rel);
  }
  return out;
}

function uncomment(f, l) {
  if (/\.(py)$/.test(f)) return l.replace(/^\s*#.*$/, "");
  if (/\.lua$/.test(f)) return l.replace(/^\s*--.*$/, "");
  return l.replace(/^\s*\/\/.*$/, "");
}

module.exports = {
  module: "morpheus/themesync.js",
  cases: (_S, t) => {
    const root = path.resolve(__dirname, "../..");
    const hypr = path.resolve(root, "../hypr");
    const bad = [];
    const scan = (base, label) => {
      if (!fs.existsSync(base)) return;
      for (const f of walk(base, "", [])) {
        fs.readFileSync(path.join(base, f), "utf8").split("\n").forEach((l, i) => {
          const s = uncomment(f, l);
          if (BAD.some(re => re.test(s))) bad.push(label + f + ":" + (i + 1) + "  " + l.trim());
        });
      }
    };
    scan(root, "");
    scan(hypr, "hypr/");
    t.eq("no key label says enter (it is return)", bad.join("\n    "), "");

    // the guard itself still catches each shape
    const hit = s => BAD.some(re => re.test(s));
    t.eq("catches a hint row", hit('[["enter", "open"]]'), true);
    t.eq("catches a modifier", hit('hint: "alt enter"'), true);
    t.eq("catches Ctrl+Enter", hit("'Ctrl+Enter'"), true);
    t.eq("catches a help line", hit('"esc  \\u00b7  enter keeps it"'), true);
    t.eq("leaves Qt.Key_Enter", hit("e.key === Qt.Key_Enter"), false);
    t.eq("leaves the verb", hit('"Enter the Clio password"'), false);
  },
};
