// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// TWO WEIGHTS (user, 2026-11-07: consistency across the board). Words wear
// Zenon.weight, Oracle's Font weight setting, or Zenon.titleWeight. A literal
// Font.Bold/DemiBold/Medium drifted (Minerva's titles were a step lighter than
// everyone's); a Text with no weight at all fell to Regular beside its
// neighbors and ignored the setting. Exempt: Alexandria's specimens, and
// Clio's document hierarchy (subheading) and what a note's own face asks for.

"use strict";

const fs = require("fs");
const path = require("path");

const SKIP_DIR = /^(oracle\/tests|oracle\/qmltests|themes|scripts|plato\/nvim|alexandria)(\/|$)/;
const EXEMPT = /^(terminus\/FontSpecimen|clio\/(Block|BlockEditor|FormatBar|TableBlock|Clio|ClioTool)|morpheus\/zenon\/)/;
const LITERAL = /\bFont\.(Bold|DemiBold|Medium)\b|font\.weight:\s*[0-9]+/g;

function walk(root, d, out) {
  for (const e of fs.readdirSync(path.join(root, d), { withFileTypes: true })) {
    const rel = d ? d + "/" + e.name : e.name;
    if (e.name.startsWith(".") || SKIP_DIR.test(rel)) continue;
    if (e.isDirectory()) walk(root, rel, out);
    else if (e.name.endsWith(".qml")) out.push(rel);
  }
  return out;
}

// the keys at depth one of a Text block: a child's weight is not the Text's
function topLevel(body, key) {
  let d = 0;
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (c === "{") d++;
    else if (c === "}") d--;
    else if (d === 0 && body.startsWith(key, i) && body[i - 1] !== ".") return true;
  }
  return false;
}

module.exports = {
  module: "morpheus/themesync.js",
  cases: (_S, t) => {
    const root = path.join(__dirname, "..", "..");
    const bad = [];
    for (const f of walk(root, "", [])) {
      if (EXEMPT.test(f)) continue;
      const s = fs.readFileSync(path.join(root, f), "utf8");
      for (const m of s.matchAll(LITERAL))
        bad.push(f + ":" + (s.slice(0, m.index).split("\n").length) + " " + m[0]);
      for (const m of s.matchAll(/^[ \t]*Text \{/gm)) {
        let i = m.index + m[0].length, d = 1;
        while (i < s.length && d) { d += s[i] === "{" ? 1 : s[i] === "}" ? -1 : 0; i++; }
        const body = s.slice(m.index + m[0].length, i);
        if (topLevel(body, "font.pixelSize") && !topLevel(body, "font.weight") && !topLevel(body, "font:"))
          bad.push(f + ":" + (s.slice(0, m.index).split("\n").length) + " Text with no weight");
      }
    }
    t.eq("every word wears Zenon.weight or Zenon.titleWeight", bad.join("\n    "), "");
  },
};
