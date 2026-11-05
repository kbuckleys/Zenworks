// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE ACCENT IS CALLED THE ACCENT (user, 2026-11-04): ThemeSync and Follow
// Background make it the background's color, seldom cyan, so code says
// Zenon.accent. Zenon.cyan is left only so a hue SAVED as "cyan" (notes,
// tags, journals, calendars, settings) still resolves as Zenon[name].
// What it catches: Zenon.cyan (or a Zenon alias's .cyan) written in code.

"use strict";

const fs = require("fs");
const path = require("path");

const SKIP_DIR = /^(oracle\/tests|oracle\/qmltests|themes|plato\/nvim)(\/|$)/;

function walk(root, d, out) {
  for (const e of fs.readdirSync(path.join(root, d), { withFileTypes: true })) {
    const rel = d ? d + "/" + e.name : e.name;
    if (e.name.startsWith(".") || SKIP_DIR.test(rel)) continue;
    if (e.isDirectory()) walk(root, rel, out);
    else if (/\.(qml|js)$/.test(e.name)) out.push(rel);
  }
  return out;
}

module.exports = {
  module: "morpheus/themesync.js",
  cases: (_S, t) => {
    const root = path.resolve(__dirname, "../..");
    const bad = [];
    for (const f of walk(root, "", [])) {
      const src = fs.readFileSync(path.join(root, f), "utf8");
      src.split("\n").forEach((l, i) => {
        if (/\b(Zenon|Z|z)\.cyan\b/.test(l.replace(/\/\/.*$/, ""))) bad.push(f + ":" + (i + 1));
      });
    }
    t.eq("the accent is Zenon.accent, never Zenon.cyan", bad.join("\n    "), "");
  },
};
