// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// folio's pure half: cliphist's list read, and the snippets — listed,
// filtered, named, and their placeholders filled.

"use strict";

module.exports = {
  module: "folio/folio.js",
  cases: (F, t) => {
    // cliphist
    const p = F.parseList("12\thello world\n11\t[[ binary data 4 KiB png 10x10 ]]\nbad line\n");
    t.eq("text entries", p.entries.map((e) => e.id), ["12"]);
    t.eq("pictures by id", p.imageIds, ["11"]);
    t.eq("filtered", F.filterEntries(p.entries, "WORLD").length, 1);

    // snippets: listed
    const snips = F.parseSnippets(JSON.stringify([
      { name: "sign-off", path: "/s/sign-off.txt", text: "Best,\nBuck" },
      { name: "Address", path: "/s/Address.txt", text: "12 Nile St" },
      { name: "", path: "/s/x.txt" }
    ]));
    t.eq("nameless dropped, by name", snips.map((s) => s.name), ["Address", "sign-off"]);
    t.eq("garbage is none", F.parseSnippets("{"), []);
    const rows = F.snippetRows(snips, "nile");
    t.eq("filtered by the text too", rows.map((r) => r.preview), ["Address"]);
    t.eq("a snippet row", [rows[0].id, rows[0].snip, rows[0].sub], ["snip:Address", true, "12 Nile St"]);

    // placeholders
    const now = new Date(2026, 9, 21, 9, 5);
    t.eq("date and time", F.expandSnippet("{date} {time}", now), "2026-10-21 09:05");
    t.eq("weekday", F.expandSnippet("on {weekday}", now), "on Wednesday");
    t.eq("the clipboard", F.expandSnippet("re: {clipboard}", now, "the plan"), "re: the plan");
    t.eq("an unknown one is left", F.expandSnippet("{nope}", now), "{nope}");
    t.eq("literal braces", F.expandSnippet("{{date}}", now), "{date}");
    t.eq("a date ahead", F.expandSnippet("{date +3d}", now), "2026-10-24");
    t.eq("a weekday back", F.expandSnippet("{weekday -1d}", now), "Tuesday");
    t.eq("a month on", F.expandSnippet("{date +1M}", now), "2026-11-21");
    t.ok("a uuid", /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(F.expandSnippet("{uuid}", now)));
    t.eq("the cursor: gone from the text, counted from the end", F.expandSnippetAt("Hi {cursor}, bye", now), { text: "Hi , bye", back: 5 });
    t.eq("no cursor, nothing to walk back", F.expandSnippetAt("plain", now).back, 0);
    t.ok("the paste walks back", F.pasteSnippetCommand("a'b", 2).indexOf("wtype -k Left") > 0 && F.pasteSnippetCommand("a'b", 2).indexOf("'a'\\''b'") > 0);

    // names
    t.eq("first words", F.snippetName("Thanks so much for the quick reply!", []), "Thanks so much for the");
    t.eq("not a taken one", F.snippetName("hello", ["Hello"]), "hello 2");
    t.eq("no file-name trouble", F.snippetName("a/b: c?", []), "ab c");
    t.eq("nothing to name it by", F.snippetName("   ", []), "Snippet");
    t.eq("a typed name made safe", F.snippetFileName("  To: Bob/Alice?\n"), "To BobAlice");
    t.eq("a name of nothing", F.snippetFileName(" / "), "");

    // hints
    t.has("snippet hints", JSON.stringify(F.hintText("snip")), "ctrl n");
    t.has("the page saves", JSON.stringify(F.hintText("edit")), "save");
    t.has("text keeps a clip", JSON.stringify(F.hintText("text")), "keep as snippet");
  }
};
