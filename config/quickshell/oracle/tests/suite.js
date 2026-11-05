// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// The suite's own apps as choices (morpheus/suite.js): what hot corners'
// "Open an app" lists above the installed ones, and how one opens.

"use strict";

module.exports = {
  module: "morpheus/suite.js",
  cases: (S, t) => {
    t.eq("a suite choice is told from a desktop entry", [S.isSuite("zen:oracle"), S.isSuite("firefox.desktop"), S.isSuite("")], [true, false, false]);
    t.eq("it opens by its ipc call", S.command("zen:oracle"), ["qs", "ipc", "call", "Oracle", "open"]);
    t.eq("one the list lacks opens nothing", S.command("zen:nope"), []);
    t.eq("an installed app is not run as one", S.command("oracle"), []);
    t.eq("the suite's name, or the entry's", [S.nameOf("zen:hermes"), S.nameOf("kitty", (id) => "Kitty " + id)], ["Control Hub", "Kitty kitty"]);
    t.eq("rows carry the prefix and a glyph, the window when no map knows",
      S.rows(() => "").slice(0, 1), [{ id: "zen:alexandria", name: "Alexandria", glyph: "\uF2D0" }]);
    t.eq("the installed list leaves out the suite's own entries",
      ["hermes", "chronos", "picasso-view", "oracle"].every((id) => S.entryIds().indexOf(id) >= 0), true);
    t.eq("every suite row is a different app", new Set(S.rows(null).map((r) => r.id)).size, S.APPS.length);
  }
};
