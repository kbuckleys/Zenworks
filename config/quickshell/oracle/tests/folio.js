// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// folio's pure half: cliphist's list read, and the snippets — listed,
// filtered, named, and their placeholders filled.

"use strict";

module.exports = {
  module: "cynosure/folio/folio.js",
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
    // values asked for (2026-11-04)
    const asks = "Dear {argument name=\"who\"}, re {argument name=\"what\" default=\"the plan\"}. {argument name=\"who\"} \u2014 {argument}";
    t.eq("arguments: each name once, with its default", F.snippetArgs(asks), [{ name: "who", def: "" }, { name: "what", def: "the plan" }, { name: "Value", def: "" }]);
    t.eq("arguments: filled, the same name twice", F.fillArgs(asks, { who: "Ada", what: "x", Value: "y" }), "Dear Ada, re x. Ada \u2014 y");
    t.eq("arguments: a default when nothing is given", F.fillArgs("{argument name=\"a\" default=\"d\"}", {}), "d");
    t.eq("arguments: braces typed stay braces", F.expandSnippet(F.fillArgs("{argument name=\"a\"}", { a: "{date}" }), now), "{date}");
    t.eq("arguments: doubled braces are not one", F.snippetArgs("{{argument}}"), []);
    t.eq("no arguments", F.snippetArgs("plain {date}"), []);
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
    // pins, kinds and pasting in turn (2026-11-03)
    t.eq("a pin, then unpinned", F.togglePin(F.togglePin([], "7", "hi"), "7"), []);
    t.eq("pins kept in order", F.togglePin([{ id: "1", text: "a" }], "2", "b").map((p) => p.id), ["1", "2"]);
    t.eq("bad pins dropped", F.parsePins('[{"id":"1","text":"a"},null,{"text":"x"}]'), [{ id: "1", text: "a" }]);
    t.eq("what a clip is", ["https://a.b/c", "/home/x/y.txt", "file:///a\nfile:///b", "#ff8800", "rgb(1, 2, 3)", "hello"].map(F.clipType),
      ["link", "file", "file", "color", "color", "text"]);
    // one file's path, for its glyph (2026-11-05)
    t.eq("an absolute path", F.clipPath("/home/b/Videos/Captures/2026-10-24-214410-DP-1.mp4"),
      { path: "/home/b/Videos/Captures/2026-10-24-214410-DP-1.mp4", name: "2026-10-24-214410-DP-1.mp4", isDir: false });
    t.eq("a trailing / is a directory", F.clipPath("/home/b/Videos/"), { path: "/home/b/Videos", name: "Videos", isDir: true });
    t.eq("~ kept for the caller", F.clipPath("~/notes.md"), { path: "~/notes.md", name: "notes.md", isDir: false });
    t.eq("a file:// URI, decoded", F.clipPath("file:///home/b/My%20Docs/cv.pdf"),
      { path: "/home/b/My Docs/cv.pdf", name: "cv.pdf", isDir: false });
    t.eq("the root", F.clipPath("/"), { path: "/", name: "/", isDir: true });
    t.eq("a space in a named file", F.clipPath("/home/b/My Videos/a.mkv").name, "a.mkv");
    t.eq("not one file", ["/a/x.mp4 /b/y.mp4", "/a/x.mp4\n/b/y.mp4", "file:///a file:///b", "/usr/bin is great",
      "hello /tmp/x.txt", "https://a.b/c.png", "/a/very/long/cut…", "", "relative/x.txt"].map(F.clipPath),
      [null, null, null, null, null, null, null, null, null]);
    const turn = F.inTurnCommand(["12", "1'3"], "/run/user/1000");
    t.has("one paste each", turn, "wl-copy --paste-once --foreground");
    t.has("ids quoted", turn, "'1'\\''3'");
    t.eq("the watcher's words never whole in the script", turn.indexOf("--type text --watch"), -1);
    // keywords for snippets (2026-11-03)
    t.eq("keywords read, bad ones dropped", F.parseKeywords('{";sig":"/s/a","x":"/s/b","a b":"/s/c",";n":3}'), { ";sig": "/s/a" });
    t.eq("by path", F.keywordsByPath({ ";sig": "/s/a" }), { "/s/a": ";sig" });
    t.eq("a new keyword lets the old go", F.setKeyword({ ";old": "/s/a", ";b": "/s/b" }, ";sig", "/s/a").keys, { ";b": "/s/b", ";sig": "/s/a" });
    t.eq("taken from another", F.setKeyword({ ";sig": "/s/b" }, ";sig", "/s/a").keys, { ";sig": "/s/a" });
    t.eq("empty takes it away", F.setKeyword({ ";sig": "/s/a" }, "", "/s/a").keys, {});
    t.eq("too short", F.setKeyword({}, "x", "/s/a").problem, "Two characters at least");
    t.eq("no spaces", F.setKeyword({}, "a b", "/s/a").problem, "One word, no spaces");
    t.eq("erase, type, walk back", F.expandKeys(2, "hi", 1), [["wtype", "-k", "BackSpace", "-k", "BackSpace"], ["wtype", "--", "hi"], ["wtype", "-k", "Left"]]);
    t.eq("nothing to do", F.expandKeys(0, "", 0), []);
  }
};
