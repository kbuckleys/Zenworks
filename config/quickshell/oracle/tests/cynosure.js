// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// The pure half of cynosure: the frecency ranking, the history file, and the
// desktop-entry field codes. The launcher is one text field over these, so
// when the ranking is right the launcher is very nearly right.
//
// The paths are checked too, because they are the one thing a rename breaks
// silently — a launcher that writes its history somewhere new simply looks
// like a launcher that forgot.

"use strict";

module.exports = {
  module: "cynosure/cynosure.js",
  cases: (C, t) => {
    // ── state paths ───────────────────────────────────────────────────────
    t.eq("history lives under the cache dir",
      C.histPath(), "/home/test/.cache/cynosure-history");
    t.eq("frecency lives beside it",
      C.freqPath(), "/home/test/.cache/cynosure-freq");

    // ── history ───────────────────────────────────────────────────────────
    t.eq("blank lines are dropped", C.parseHistory("a\n\n b \n").length, 2);
    t.eq("empty history is empty", C.parseHistory("").length, 0);
    t.eq("null history is empty", C.parseHistory(null).length, 0);

    const H = C.addHistory([], "htop", "Process", C.ICON_P);
    t.eq("a run is remembered", H.length, 1);
    t.has("the mode's glyph is on the line", H[0], C.ICON_P);
    const H2 = C.addHistory(H, "htop", "Process", C.ICON_P);
    t.eq("running it again does not duplicate it", H2.length, 1);
    t.eq("deleting a line removes it",
      C.deleteHistoryLine(H2, H2[0]).length, 0);

    // ── frecency ──────────────────────────────────────────────────────────
    let f = {};
    f = C.bumpFreq(f, "firefox");
    f = C.bumpFreq(f, "firefox");
    f = C.bumpFreq(f, "htop");
    t.eq("counts accumulate", f["firefox"], 2);
    t.eq("a first run counts once", f["htop"], 1);
    t.eq("an empty key is ignored",
      Object.keys(C.bumpFreq({}, "")).length, 0);

    // The whole point of the frecency file: what you run most is on top.
    const apps = [
      { name: "htop", exec: "htop", id: "htop", icon: "" },
      { name: "firefox", exec: "firefox %u", id: "firefox", icon: "" }
    ];
    const rows = C.buildRows(apps, [], f);
    t.eq("the most-run app is first", rows[0].key, "firefox");

    // A history line that names an app already in the list would show the
    // same thing twice, one row apart.
    const dupe = C.buildRows(apps, [C.ICON_T + " firefox"], f);
    t.eq("history does not duplicate an app",
      dupe.filter((r) => r.key.toLowerCase() === "firefox").length, 1);

    // ── desktop entries ───────────────────────────────────────────────────
    // Field codes are the launcher's job to strip: %u is for a caller with a
    // URL to pass, and there isn't one here.
    t.eq("a url placeholder is dropped",
      C.stripFieldCodes("firefox %u"), "firefox");
    t.eq("a file placeholder is dropped",
      C.stripFieldCodes("gimp %F"), "gimp");
    t.eq("several are dropped",
      C.stripFieldCodes("app %f %i %c"), "app");
    t.eq("a plain command is untouched",
      C.stripFieldCodes("htop"), "htop");
    // %% is a literal percent and not a field code, and neither is a bare %.
    t.eq("an ordinary argument survives",
      C.stripFieldCodes("sh -c 'x 100%'"), "sh -c 'x 100%'");
    t.eq("%% is the % it stands for, not two",
      C.stripFieldCodes("date +%%H:%%M %u"), "date +%H:%M");
    t.eq("%%f is a literal %f, not a field code",
      C.stripFieldCodes("printf %%f"), "printf %f");

    // ── filtering ─────────────────────────────────────────────────────────
    // ── the shell's verbs ─────────────────────────────────────────────────
    const acts = C.buildRows(apps, [], {}, C.SHELL_ACTIONS);
    t.eq("every verb not waiting on something is a row", acts.filter((r) => r.kind === "shell").length,
      C.SHELL_ACTIONS.filter((a) => !a.needs).length);
    const ready = { wifiReady: true, btReady: true, nightReady: true };
    t.eq("every verb is a row once what it needs is there",
      C.buildRows(apps, [], {}, C.SHELL_ACTIONS, ready).filter((r) => r.kind === "shell").length, C.SHELL_ACTIONS.length);
    t.eq("wi-fi is not offered without it", C.filterRows(acts, "wireless").filter((r) => r.kind === "shell").length, 0);
    t.eq("…and says what pressing it does", C.filterRows(C.buildRows(apps, [], {}, C.SHELL_ACTIONS, Object.assign({ wifiOff: true }, ready)), "wireless")
      .map((r) => r.text).join(), "Wi-Fi on");
    t.eq("the night light, by the sun's word", C.filterRows(C.buildRows(apps, [], {}, C.SHELL_ACTIONS, Object.assign({ night: true }, ready)), "hyprsunset")
      .map((r) => r.text).join(), "Night light off");
    // the shell's own .desktop and its verb share a name: one row
    const hub = C.buildRows([{ name: "Control Hub", exec: "qs ipc call Hermes window", id: "hermes" }], [], {}, C.SHELL_ACTIONS);
    t.eq("an app and a verb of one name are one row", hub.filter((r) => r.text === "Control Hub").length, 1);
    t.eq("…found by the verb's words", C.filterRows(hub, "bluetooth vpn").length > 0 ? C.filterRows(hub, "brightness").filter((r) => r.text === "Control Hub").length : 1, 1);
    t.eq("found by a key, not only its name",
      C.filterRows(acts, "poweroff").map((r) => r.text).join(), "Shutdown");
    t.ok("nothing ends a session without a confirm",
      C.SHELL_ACTIONS.every((a) => a.confirm || !/systemctl|terminate-session|hyprshutdown/.test(a.sh || a.ipc)));
    t.eq("all four session verbs ask first",
      C.SHELL_ACTIONS.filter((a) => a.confirm).map((a) => a.name).join(), "Log out,Suspend,Reboot,Shutdown");
    t.eq("{session} is the logind session",
      C.actionCommand({ sh: "loginctl terminate-session {session}" }, "/q", "3"), "loginctl terminate-session 3");
    t.eq("a verb runs through ipc",
      C.actionCommand({ ipc: "Ceres window history" }, "/q"), "qs ipc call Ceres window history");
    t.eq("{dir} is the shell's directory, quoted",
      C.actionCommand({ sh: "{dir}/x" }, "/a b"), "'/a b'/x");
    t.eq("even with a quote in it",
      C.actionCommand({ sh: "{dir}/x" }, "/it's"), "'/it'\\''s'/x");
    // qs kill crashes this config (see scripts/restart.sh); restart.sh is
    // the one way to bounce it that oracle and icarus already use
    t.has("Reload shell goes through restart.sh",
      C.actionCommand(C.SHELL_ACTIONS.find(a => a.name === "Reload shell"), "/q"),
      "'/q'/scripts/restart.sh");
    t.ok("an app and a verb of the same name keep separate counts",
      C.actionKey({ name: "Files" }) !== "Files");
    const awakeRow = (on) => C.buildRows([], [], {}, C.SHELL_ACTIONS, { awake: on })
      .find((r) => r.key === "shell:Caffeinate");
    t.eq("off offers Caffeinate", awakeRow(false).text, "Caffeinate");
    t.eq("on offers Decaffeinate", awakeRow(true).text, "Decaffeinate");
    t.eq("each wears its own cup", awakeRow(true).glyph + awakeRow(false).glyph, "\u{F0FAB}\u{F06CA}");
    t.eq("a glyph splits off its label", C.splitGlyph("G  Back"), { glyph: "G", label: "Back" });
    t.eq("a bare label has no glyph", C.splitGlyph("Back"), { glyph: "", label: "Back" });
    t.eq("the count survives the flip", awakeRow(true).key, awakeRow(false).key);
    const glyphOf = (names) => names.indexOf("firefox.desktop") >= 0 ? "G" : "";
    const withG = C.buildRows([{ name: "Firefox", exec: "firefox %u", id: "firefox.desktop" },
      { name: "kitty", exec: "kitty", id: "kitty.desktop" }], [], {}, [], {}, glyphOf);
    t.eq("an app with a program glyph wears it",
      withG.find((r) => r.text === "Firefox").displayText, "G  Firefox");
    t.eq("an app without one shows none", withG.find((r) => r.text === "kitty").displayText, "kitty");
    const bumped = C.buildRows(apps, [], { "shell:Calculator": 5 }, C.SHELL_ACTIONS);
    t.eq("a used verb ranks like a used app", bumped[0].text, "Calculator");
    const all = C.buildRows(apps, [], {});
    t.eq("a query narrows the list",
      C.filterRows(all, "fire").length, 1);
    const kw = C.buildRows(C.getApps([{ name: "Alexandria", exec: "alexandria %F", id: "alexandria",
                                       words: "Font Book font typeface glyph" }]), [], {});
    t.eq("an app's keywords find it", C.filterRows(kw, "typeface").map((r) => r.text), ["Alexandria"]);
    t.eq("so does its generic name", C.filterRows(kw, "font book").map((r) => r.text), ["Alexandria"]);
    t.eq("an empty query keeps everything",
      C.filterRows(all, "").length, all.length);
    t.eq("a query matching nothing gives nothing",
      C.filterRows(all, "zzzzz").length, 0);

    // ── the panel's list (2026-11-01) ─────────────────────────────────────
    const ranked = C.rankRows(C.buildRows(C.getApps([
      { name: "Thunar", exec: "thunar", id: "thunar" },
      { name: "Firefox", exec: "firefox", id: "firefox" },
      { name: "Fire Starter", exec: "fs", id: "fs" }]), [], {}), "fire");
    t.eq("a name starting with the query comes first, then a word of one",
      ranked.map((r) => r.text), ["Fire Starter", "Firefox"]);
    t.eq("rank finds what the old filter found",
      C.rankRows(kw, "typeface").map((r) => r.text), ["Alexandria"]);

    const root = C.rootRows(all, "", { firefox: 3 }, C.SHELL_ACTIONS, {});
    t.eq("an empty line starts with what is used", root[0].section, "Suggestions");
    t.eq("…and the used row is not listed twice",
      root.filter((r) => r.text === "firefox").length, 1);
    t.ok("every row has a heading", root.every((r) => !!r.section));
    t.ok("…and the rows are copies, not the ranked ones", all.every((r) => r.section === undefined));

    // ── what you searched ────────────────────────────────────────────────
    t.eq("newest first, once", C.addQuery(["b", "a"], " a "), ["a", "b"]);
    t.eq("nothing is not a search", C.addQuery(["a"], "  "), ["a"]);
    t.eq("thirty at most", C.addQuery(Array.from({ length: 30 }, (_, i) => "q" + i), "new").length, 30);
    t.eq("kept round", C.parseQueries(C.serializeQueries(["x", "y"])), ["x", "y"]);

    // ── your scripts ─────────────────────────────────────────────────────
    const scripts = C.parseScripts("\u001e/s/restart-waybar.sh\n# @title Restart Waybar\n# @mode silent\n"
      + "\u001e/s/weather.py\n# @argument a city\n# @word wx\n# @mode output\n"
      + "\u001e/s/plain\n");
    t.eq("a script's header read", scripts[0], { path: "/s/restart-waybar.sh", title: "Restart Waybar", glyph: "\uF489",
      mode: "silent", argument: "", refresh: 0, word: "restart-waybar", keywords: "" });
    t.eq("no title: its file's name", scripts[2].title, "Plain");
    t.eq("one that takes words", C.scriptFor(scripts, "wx cairo").arg, "cairo");
    t.eq("first in the list", C.rootRows(all, "wx cairo", {}, C.SHELL_ACTIONS, { scripts })[0].kind, "script");
    t.eq("one that does not, a command that runs", C.scriptActions(scripts)[0].inline, "script");
    t.eq("one that does, a command that types its word", C.scriptActions(scripts)[1].line, "wx ");
    t.ok("the new one's header reads back", C.parseScripts("\u001e/s/new.sh\n" + C.scriptTemplate().split("\n").filter((l) => /@/.test(l)).join("\n"))[0].word === "mine");

    // ── open windows ─────────────────────────────────────────────────────
    const wins = [{ address: "0x1", title: "README.md — Plato", app: "org.quickshell", name: "Plato", ws: "2", focused: true },
      { address: "0x2", title: "Inbox — Mozilla Firefox", app: "firefox", name: "firefox", ws: "1" }];
    t.eq("a line finds the windows it names", C.windowRows(wins, "fire", false, null).map((r) => r.address), ["0x2"]);
    t.eq("nothing typed, no windows in the list", C.windowRows(wins, "", false, null).length, 0);
    t.eq("\"win\" alone is every one, where you are last",
      C.windowRows(wins, "", true, null).map((r) => r.address), ["0x2", "0x1"]);
    t.eq("said where it is", C.windowRows(wins, "inbox", false, null)[0].sub, "firefox \u00B7 workspace 1");
    t.eq("\"win …\" is the windows and nothing else",
      C.rootRows(all, "win fire", {}, C.SHELL_ACTIONS, { windows: C.windowRows(wins, "fire", true, null), windowsOnly: true }).map((r) => r.kind),
      ["window"]);
    t.ok("\"win\" is Cynosure's own word", C.aliasProblem("win") !== "");

    // ── quick links ──────────────────────────────────────────────────────
    const links = C.allLinks([]);
    const gh = C.linkFor(links, "gh zen works");
    t.eq("a word and words are a search there", gh && gh.url, "https://github.com/search?q=zen%20works");
    t.eq("said as one", gh && gh.label, "Search GitHub for \u201Czen works\u201D");
    t.eq("the word alone opens the site", C.linkFor(links, "yt ").url, "https://www.youtube.com");
    t.eq("no word, no link", C.linkFor(links, "firefox now"), null);
    t.eq("first in the list", C.rootRows(all, "gh zen", {}, C.SHELL_ACTIONS, { links })[0].kind, "link");
    t.ok("the web is a fallback", C.rootRows(all, "zzz", {}, C.SHELL_ACTIONS, { links }).some((r) => r.kind === "link" && r.label === "Search the web"));
    const own = C.readLink("jira https://acme.atlassian.net/browse/{q}");
    t.eq("yours, read", own.link, { word: "jira", name: "Atlassian", url: "https://acme.atlassian.net/browse/{q}" });
    t.eq("yours take a built-in's word", C.linkFor(C.allLinks([{ word: "g", name: "Gitea", url: "https://git.me/?q={q}" }]), "g x").url, "https://git.me/?q=x");
    t.ok("an address is needed", !!C.readLink("x notalink").problem);
    t.ok("Cynosure's words stay its own", !!C.readLink("cb https://a.b/{q}").problem);
    t.ok("every link is a command with its word on it",
      C.linkActions(links).every((a) => a.line === a.alias + " " && / search$/.test(a.name)));

    // ── aliases ──────────────────────────────────────────────────────────
    const ffRow = all.find((r) => r.text === "firefox");
    const amap = C.setAlias({}, "FF", ffRow);
    t.eq("an alias is kept lowercase, for its row", Object.keys(amap), ["ff"]);
    t.eq("a second word for it replaces the first", Object.keys(C.setAlias(amap, "web", ffRow)), ["web"]);
    t.eq("removed", Object.keys(C.dropAlias(amap, ffRow)), []);
    const aliased = C.withAliases(all, amap);
    t.eq("the row wears it", aliased.find((r) => r.text === "firefox").alias, "ff");
    t.eq("typed whole, it is the top result",
      C.rootRows(aliased, "ff", {}, C.SHELL_ACTIONS, {})[0].text, "firefox");
    t.eq("a file can have one too",
      C.aliasFiles({ cv: { kind: "file", key: "/home/test/cv.pdf", path: "/home/test/cv.pdf" } }, "cv", "/home/test", null)[0].alias, "cv");
    t.eq("one word only", C.aliasProblem("my app"), "An alias is one word");
    t.ok("Cynosure's own words are refused", C.aliasProblem("cb") !== "");
    t.eq("a fine word is fine", C.aliasProblem("ff"), "");
    t.eq("the file is kept round", C.parseAliases(C.serializeAliases(amap)), amap);

    // ── top results ──────────────────────────────────────────────────────
    const tops = C.rootRows(all, "fire", { firefox: 2 }, C.SHELL_ACTIONS, {
      files: C.fileRows(["/home/test/firewall.conf", "/home/test/campfire.txt"], "/home/test", null),
      fileFreq: { "/home/test/firewall.conf": 9 } });
    t.eq("the best named matches come first, one section",
      tops.filter((r) => r.section === "Top results").map((r) => r.label), ["firewall.conf", "firefox"]);
    t.ok("…and are not listed again below",
      tops.filter((r) => r.label === "firefox").length === 1 && tops.filter((r) => r.label === "firewall.conf").length === 1);
    t.ok("a match in the middle of a name is not a top result",
      !tops.some((r) => r.section === "Top results" && r.label === "campfire.txt"));
    const typed = C.rootRows(all, "fire", {}, C.SHELL_ACTIONS, {});
    t.eq("a typed line ends in running it", typed.slice(-2).map((r) => r.kind + ":" + r.mode),
      ["run:Terminal", "run:Process"]);
    const files = C.fileRows(["/home/test/Documents/report.pdf", "/home/test/Projects/"], "/home/test", null);
    t.eq("a file row is its name over where it is",
      files.map((r) => r.label + "|" + r.sub + "|" + r.isDir), ["report.pdf|~/Documents|false", "Projects|~|true"]);
    const withFiles = C.rootRows(all, "fire", {}, C.SHELL_ACTIONS, { files });
    t.ok("files come after the apps, before the line run",
      withFiles.findIndex((r) => r.kind === "file") > withFiles.findIndex((r) => r.kind === "app")
      && withFiles.findIndex((r) => r.kind === "file") < withFiles.findIndex((r) => r.kind === "run"));
    t.eq("\"f …\" is the files and nothing else",
      C.rootRows(all, "f report", {}, C.SHELL_ACTIONS, { files, filesOnly: true }).map((r) => r.section),
      ["Files", "Files"]);
    const ents = [{ id: "7", content: "invoice 2041", preview: "invoice 2041" }, { id: "6", content: "hello", preview: "hello" }];
    const snips = [{ name: "sig", path: "/s/sig.txt", text: "Kind regards" }];
    t.eq("a line finds a few clips and snippets", C.clipRows(ents, ["9"], snips, "invo", false, null, null).map((r) => r.kind + ":" + r.label),
      ["clip:invoice 2041"]);
    t.eq("\"cb\" alone is the newest pictures as a grid above the clips, then the snippets",
      C.clipRows(ents, ["9", "5", "4"], snips, "", true, null, null, 2).map((r) => r.kind + (r.cells ? r.cells.length : "")),
      ["pics2", "pics1", "clip", "clip", "snip"]);
    t.eq("\"cb pictures\" is the pictures alone, rows of four",
      C.clipRows(ents, ["9", "8", "7", "6", "5"], snips, "pictures", true, null, null, 4).map((r) => r.cells.length), [4, 1]);
    t.eq("one letter is not worth a clip", C.clipRows(ents, [], snips, "i", false, null, null).length, 0);
    t.eq("\"cb …\" is the clipboard and nothing else",
      C.rootRows(all, "cb inv", {}, C.SHELL_ACTIONS, { clips: C.clipRows(ents, [], snips, "inv", true, null, null), clipsOnly: true }).map((r) => r.section),
      ["Clipboard"]);
    const emo = [{ char: "😀", name: "grinning face" }, { char: "😃", name: "grinning face with big eyes" }, { char: "🐱", name: "cat face" }];
    t.eq("a line finds one strip of emoji", C.glyphRows(emo, "grin", false, false, 14).map((r) => r.cells.length), [2]);
    t.eq("\"em\" alone is the set, a strip at a time", C.glyphRows(emo, "", false, true, 2).map((r) => r.cells.length), [2, 1]);
    t.eq("one letter is not worth a strip", C.glyphRows(emo, "g", false, false, 14).length, 0);
    t.eq("\"calc …\" leaves the list to the calculator", C.rootRows(all, "calc 2+2", {}, C.SHELL_ACTIONS, {}).length, 0);

    const sc = C.scopedRow(C.SHELL_ACTIONS, "cb invoice 12");
    t.eq("an alias hands the rest to its panel", sc && [sc.view, sc.rest], ["folio", "invoice 12"]);
    t.eq("…said as what it will do", sc && sc.label, "Search the clipboard for \u201Cinvoice 12\u201D");
    t.eq("a god's name works as its alias", C.scopedRow(C.SHELL_ACTIONS, "lexi serendipity").view, "lexi:dict");
    t.eq("the word alone, then a space, is the panel opened empty",
      C.scopedRow(C.SHELL_ACTIONS, "tr ").label, "Translate");
    t.eq("no space yet, no panel", C.scopedRow(C.SHELL_ACTIONS, "cb"), null);
    t.eq("a word nothing answers to is no panel", C.scopedRow(C.SHELL_ACTIONS, "htop -d 2"), null);
    t.ok("a scoped line is not also offered to the shell",
      !C.rootRows(all, "cb report", {}, C.SHELL_ACTIONS, {}).some((r) => r.kind === "run"));
    const aliases = C.SHELL_ACTIONS.filter((a) => a.alias).map((a) => a.alias);
    t.eq("no two panels share a word", new Set(aliases).size, aliases.length);

    // ── the actions panel ────────────────────────────────────────────────
    const kinds = ["app", "shell", "hist", "file", "clip", "clipimg", "pics", "snip", "glyphs", "calc", "run", "fallback", "scoped"];
    t.ok("every row kind has actions, return's first",
      kinds.every((k) => { const x = C.rowActions({ kind: k, action: {} }); return x.length > 0 && x[0].id === "go" && x[0].hint === "return"; }));
    t.ok("no action twice in a panel",
      kinds.every((k) => { const ids = C.rowActions({ kind: k, action: {} }).map((x) => x.id); return new Set(ids).size === ids.length; }));
    // the dictionary and the translator, read off the line
    const L = (q) => { const x = C.parseLexi(q); if (!x) return null;
      const c = (l) => l ? l.code : null;
      return x.mode === "dict" ? ["dict", x.word, c(x.lang)] : ["trans", x.text, c(x.to), c(x.from)]; };
    t.eq("define", L("define serendipity"), ["dict", "serendipity", null]);
    t.eq("def in a language", L("def faire in french"), ["dict", "faire", "fr"]);
    t.eq("bare def", L("def "), ["dict", "", null]);
    t.eq("X meaning", L("serendipity meaning"), ["dict", "serendipity", null]);
    t.eq("what does X mean", L("what does ephemeral mean?"), ["dict", "ephemeral", null]);
    t.eq("meaning of", L("meaning of life"), ["dict", "life", null]);
    t.eq("tr", L("tr good morning"), ["trans", "good morning", null, null]);
    t.eq("tr to a language", L("translate hola to english"), ["trans", "hola", "en", null]);
    t.eq("from and to", L("tr merci from french to german"), ["trans", "merci", "de", "fr"]);
    t.eq("X in a language", L("hello in spanish"), ["trans", "hello", "es", null]);
    t.eq("two-word language", L("thank you in simplified chinese"), ["trans", "thank you", "zh-CN", null]);
    t.eq("how do you say", L("how do you say cat in german?"), ["trans", "cat", "de", null]);
    t.eq("time in a city is not a translation", L("time in tokyo"), null);
    t.eq("money is not either", L("5 usd in eur"), null);
    t.eq("an app is nothing", L("firefox"), null);
    // settings, the store, notes, packages
    const pages = [{ id: "fonts", label: "Fonts", icon: "F" }, { id: "display", label: "Display", icon: "D" }];
    const schema = [{ key: "fontFamily", section: "fonts", label: "Font", help: "the type" },
      { key: "fontSize", section: "fonts", within: "fontFamily", label: "Font size", help: "how large" },
      { key: "infoPath", section: "fonts", label: "Written to", type: "info" },
      { key: "mainMonitor", section: "display", label: "Main monitor", alias: "primary screen" }];
    t.eq("font size finds the row, opened at its host", C.settingsRows(schema, pages, "font size", false).map((r) => r.label + ">" + r.spec),
      ["Font size>fontFamily"]);
    t.eq("a page by name", C.settingsRows(schema, pages, "display", false).map((r) => r.label), ["Display"]);
    t.eq("settings … finds by alias", C.settingsRows(schema, pages, "primary", true).map((r) => r.label), ["Main monitor"]);
    t.eq("short lines ask nothing", C.settingsRows(schema, pages, "fo", false), []);
    t.eq("info rows are not settings", C.settingsRows(schema, pages, "written", true), []);
    const sapps = [{ key: "a:obs", name: "OBS Studio", pkg: "obs-studio", summary: "Record", dev: "", keywords: [], installed: false, source: "arch" },
      { key: "a:gimp", name: "GIMP", pkg: "gimp", summary: "Paint", dev: "", keywords: [], installed: true, source: "arch" }];
    t.eq("the store, by Ceres' search", C.storeRows(sapps, "obs").map((r) => r.label + ":" + r.app), ["OBS Studio:a:obs"]);
    t.ok("an app not installed can be installed", C.rowActions(C.storeRows(sapps, "obs")[0]).some((x) => x.id === "storeInstall"));
    t.eq("installed: no install", C.rowActions(C.storeRows(sapps, "gimp")[0]).some((x) => x.id === "storeInstall"), false);
    const cnotes = [{ id: "n1", kind: "note", blocks: [{ k: "title", h: "Buy oat milk" }, { k: "body", h: "and bread" }], modified: 2 },
      { id: "n2", kind: "note", blocks: [{ k: "title", h: "Ideas" }, { k: "body", h: "oat cookies" }], modified: 1 },
      { id: "n3", kind: "note", deleted: 5, blocks: [{ k: "title", h: "Oat gone" }] }];
    t.eq("notes … by Clio's score, title first, the trash left out", C.noteRows(cnotes, "oat", true).map((r) => r.label), ["Buy oat milk", "Ideas"]);
    t.eq("any line: only a title match", C.noteRows(cnotes, "buy oat", false).map((r) => r.label), ["Buy oat milk"]);
    t.eq("a new note's row", C.newNoteRow("call mum").label, "New note \u201Ccall mum\u201D");
    t.eq("no words, no row", C.newNoteRow("  "), null);
    const pk = C.packageRows([{ name: "paru", installed: true, aur: true, repo: "aur", version: "2.2" },
      { name: "obs-studio", installed: false, aur: false, repo: "extra", version: "33" }]);
    t.eq("packages say where from", pk.map((r) => r.sub), ["AUR \u00B7 2.2", "extra \u00B7 33"]);
    t.eq("return removes what is installed, installs the rest", pk.map((r) => C.verbOf(r)), ["remove", "install"]);
    const fri = new Date(2026, 9, 28, 10, 0);   // a Wednesday
    const ev = C.eventRow("lunch with sam friday 1pm @ Luigi's", "2026-10-28", fri);
    t.eq("an event read as Chronos reads it", [ev.label, ev.sub], ["lunch with sam", "Friday 30 October \u00B7 13:00 \u2013 14:00 \u00B7 Luigi's"]);
    t.eq("only when, no what", C.eventRow("tomorrow 3pm", "2026-10-28", fri).bad, true);
    // recent glyphs lead
    const gents = [{ char: "a", name: "apple" }, { char: "b", name: "banana" }, { char: "c", name: "cherry" }];
    const gr = C.glyphRows(gents, "", false, true, 2, ["c"]);
    t.eq("recent glyphs get their own strip first", gr.map((r) => r.section + ":" + r.cells.map((c) => c.char).join("")),
      ["Recently used:c", "Emoji:ab"]);
    // "nf" alone lists every glyph, not the first twelve strips (2026-11-05)
    const nfs = [];
    for (let i = 0; i < 500; i++) nfs.push({ char: String.fromCharCode(0xE000 + i), cls: "nf-x-" + i, name: "x " + i });
    const nfr = C.glyphRows(nfs, "", true, true, 11, []);
    t.eq("the whole Nerd set is listed", nfr.reduce((s, r) => s + r.cells.length, 0), 500);
    const nfRecent = nfs.slice(0, 30).map((e) => e.char);
    const nfu = C.glyphRows(nfs, "", true, true, 11, nfRecent);
    t.eq("recents past their strips are back in the set, none lost",
      nfu.reduce((s, r) => s + r.cells.length, 0), 500);
    t.eq("recents survive a write", C.addGlyph(C.parseGlyphs(JSON.stringify({ emoji: ["x"] })), "y", false).emoji, ["y", "x"]);
    // hotkeys
    const app = { kind: "app", key: "Firefox", id: "firefox.desktop", label: "Firefox", glyph: "G", score: 3 };
    let hk = C.setHotkey([], "SUPER + F", app);
    t.eq("a hotkey keeps the row's plain data", hk[0].row, { kind: "app", key: "Firefox", id: "firefox.desktop", label: "Firefox", glyph: "G" });
    t.eq("found again by its row", C.hotkeyOf(hk, { kind: "app", key: "Firefox" }), "SUPER + F");
    hk = C.setHotkey(hk, "SUPER + G", app);
    t.eq("a row has one chord", hk.map((h) => h.chord), ["SUPER + G"]);
    t.eq("dropped", C.dropHotkey(hk, app), []);
    t.ok("the lua binds it", C.renderHotkeysLua(hk).indexOf('{ chord = "SUPER + G", label = "Cynosure: Firefox" }') >= 0);
    t.eq("junk is not a hotkey", C.parseHotkeys('[{"chord":"X"},{"chord":"SUPER + A","row":{"kind":"clip"}}]'), []);
    t.ok("apps offer a hotkey", C.rowActions(app).some((x) => x.id === "setHotkey"));
    t.ok("windows can float", C.rowActions({ kind: "window" }).some((x) => x.id === "winFloat"));
    t.eq("no move here for a window already here", C.rowActions({ kind: "window", here: true }).some((x) => x.id === "winHere"), false);
    t.eq("a nerd glyph copies in three formats", C.rowActions({ kind: "glyphs", nerd: true }).map((x) => x.id), ["go", "copyName", "copyCode"]);
    t.eq("a nerd codepoint", C.codepoints("\uF0C5"), "U+F0C5");
    t.eq("an emoji's codepoints, joiners and selectors left out", C.codepoints("\u{1F44D}\u{1F3FD}\u2764\uFE0F"), "U+1F44D U+1F3FD U+2764");
    t.eq("a directory is not opened with an app", C.rowActions({ kind: "file", isDir: true }).some((x) => x.id === "openWith"), false);
    t.ok("a digit is worth a sum", C.wantsCalc("5 km in miles", "qalc"));
    t.ok("an app name is not", !C.wantsCalc("firefox", "qalc"));
    t.ok("nor a date word without a number", !C.wantsCalc("today", "local"));
    t.ok("a leading = always is", C.wantsCalc("=pi", "qalc"));
    t.ok("a time somewhere is", C.wantsCalc("time in sydney", "tz"));
    t.ok("a conversion in words is", C.wantsCalc("usd to eur", "qalc"));
    t.ok("but two words are not a conversion", !C.wantsCalc("open terminal", "qalc"));
    t.ok("a date in words is", C.wantsCalc("days until christmas", "local"));
    t.ok("but one date word alone is not", !C.wantsCalc("tomorrow", "local"));
    t.ok("a bare = is not yet", !C.wantsCalc("=", "qalc"));
    t.eq("the = is not part of the sum", C.calcQuestion("= 2^10"), "2^10");

    // ── commands ──────────────────────────────────────────────────────────
    // The terminal has to be footclient by name: xdg-terminal-exec drops
    // --hold unless the desktop entry declares TerminalArgHold, and foot's
    // does not — which is what made every terminal launch close instantly.
    const term = C.terminalCommand("duf");
    t.has("footclient is called directly", term, "footclient");
    t.has("the window is held open", term, "--hold");
    t.has("the title matches the hyprland rule", term, "--title=cynosure");

    // With oracle's terminal named, that is the one used: xdg-terminal-exec
    // reads xdg-terminals.list, which oracle keeps in step with it.
    const kit = C.terminalCommand("duf", "kitty");
    t.has("a chosen terminal goes through xdg-terminal-exec", kit, "xdg-terminal-exec --title=cynosure --hold -e");
    t.ok("and never footclient", kit.indexOf("footclient") < 0);
    t.has("foot chosen is still called by name", C.terminalCommand("duf", "/usr/bin/foot"),
      "footclient --hold --title=cynosure");
    t.has("there is a fallback for other machines", term, "xdg-terminal-exec");

    // gio launch, NOT gtk-launch: gtk-launch runs the Exec line and nothing
    // else, so a Terminal=true entry died the moment it started. This is the
    // regression that check exists to catch.
    // BY THE BARE ID, because that is what DesktopEntries hands back: `htop`,
    // `discord`, `org.kde.okular` — quickshell never puts the `.desktop` on
    // the end. Every path built below is gated on `[ -f ]`, so an id used raw
    // matches no file, every directory is skipped, the loop falls through to
    // `exit 1`, and the caller's >/dev/null swallows it. That is a launcher
    // that launches nothing at all, in total silence. Asserted with the bare
    // id precisely because the fixture used to carry a suffix of its own and
    // so agreed with a bug the real DesktopEntries would never have allowed.
    const launch = C.launchAppCommand("htop");
    t.has("the id is resolved to a real file name", launch, "htop.desktop");
    t.ok("and not left bare, which would match nothing",
      launch.indexOf("\"htop\"") === -1 && launch.indexOf("'htop'") === -1);
    t.has("an app is launched with gio, which honors Terminal=true",
      launch, "gio launch");
    t.ok("gtk-launch is gone", launch.indexOf("gtk-launch") === -1);
    t.has("through the XDG search path", launch, "XDG_DATA_DIRS");
    t.has("starting with the user's own", launch, "XDG_DATA_HOME");
    // A stale user override must not be the end of the search: it stops at the
    // first entry that LAUNCHES, not the first that exists.
    t.has("it keeps trying until one launches", launch, "&& exit 0");
    t.has("and reports failure when none does", launch, "exit 1");
    t.ok("every candidate is tried, not just the first",
      launch.indexOf("for d in") === 0);
    // terminus already holds a file name, having read one off a directory.
    // Appending unconditionally would send it looking for htop.desktop.desktop.
    t.ok("an id that is already a file name is left alone",
      C.launchAppCommand("htop.desktop").indexOf("htop.desktop.desktop") === -1);

    {
      // ── tasks and reminders (2026-11-02) ──────────────────────────────────
      const now = new Date(2026, 10, 2, 10, 0);
      const w = (x) => C.taskWhen(x, now);
      t.eq("in 20 min", w("in 20 min to call mom").due, now.getTime() + 20 * 60000);
      t.eq("the task is the rest, without its to", w("in 20 min to call mom").title, "Call mom");
      t.eq("in an hour", w("stretch in an hour").due, now.getTime() + 3600000);
      t.eq("half an hour", w("in half an hour tea").due, now.getTime() + 1800000);
      t.eq("at 5pm today", w("call bob at 5pm").due, new Date(2026, 10, 2, 17, 0).getTime());
      t.eq("a clock gone by is tomorrow's", w("call bob at 9am").due, new Date(2026, 10, 3, 9, 0).getTime());
      t.eq("a day alone is nine that morning", w("pay rent friday").due, new Date(2026, 10, 6, 9, 0).getTime());
      t.eq("and the day is not the task", w("pay rent friday").title, "Pay rent");
      t.eq("no when, no time", w("buy milk").due, 0);
      t.ok("only a when is no task", !!w("tomorrow at 9").error);
      const rem = C.newTaskRow("buy milk", true, now);
      t.ok("a reminder needs a when", rem.bad);
      const todo = C.newTaskRow("buy milk", false, now);
      t.ok("a task does not", !todo.bad && todo.due === 0);
      t.has("a timed row says when", C.newTaskRow("in 20 min to call mom", true, now).sub, "10:20");
      const tasks = C.taskRows([{ id: "n1", kind: "note", blocks: [{ k: "title", h: "Home" },
        { k: "check", h: "Water plants", c: false }, { k: "check", h: "Done one", c: true }] }], "", now);
      t.eq("open items only", tasks.length, 1);
      t.eq("under Clio's group", tasks[0].section, "No date");
      t.eq("found by its words", C.taskRows([{ id: "n1", kind: "note", blocks: [{ k: "check", h: "Water plants", c: false }] }],
        "plants", now).length, 1);

      // ── books, outputs, colors (2026-11-02) ───────────────────────────────
      const books = C.bookRows([{ path: "/a.pdf", kind: "pdf", title: "Alpha", author: "Ann", opened: 1, progress: 0.5 },
        { path: "/b.epub", kind: "epub", title: "Beta", author: "", opened: 5, progress: 0, finished: 9 }], "");
      t.eq("the last read first", books[0].label, "Beta");
      t.has("finished says so", books[0].sub, "Finished");
      t.has("else how far", books[1].sub, "50%");
      t.eq("found by author", C.bookRows([{ path: "/a.pdf", kind: "pdf", title: "Alpha", author: "Ann" }], "ann").length, 1);
      const outs = C.outputRows([{ id: 3, name: "a", label: "Speakers" }, { id: 4, name: "b", label: "Headphones" }], 4, "");
      t.eq("the one in use says so", outs[1].sub, "In use");
      t.eq("found by name", C.outputRows([{ id: 3, name: "a", label: "Speakers" }], 0, "spea").length, 1);
      t.eq("a color by its hex", C.colorRows(["#ff0000", "#00ff00"], "#ff")[0].label, "#FF0000");
      t.eq("wearing itself", C.colorRows(["#ff0000"], "")[0].ink, "#ff0000");

      // ── favorites (2026-11-02) ────────────────────────────────────────────
      const app = { kind: "app", key: "Firefox", label: "Firefox", text: "Firefox", id: "firefox" };
      const file = { kind: "file", key: "/x", path: "/x", label: "x", text: "x" };
      let fav = C.addFavorite([], app);
      fav = C.addFavorite(fav, file);
      t.eq("kept once", C.addFavorite(fav, app).length, 2);
      t.ok("known again", C.isFavorite(fav, Object.assign({}, app, { section: "Applications" })));
      t.eq("moved up", C.moveFavorite(fav, file, -1)[0].kind, "file");
      t.eq("not past the top", C.moveFavorite(fav, app, -1)[0].kind, "app");
      t.eq("dropped", C.dropFavorite(fav, app).length, 1);
      t.eq("a file as kept, the rest as the list has them", C.favoriteRows(fav, [Object.assign({}, app, { sub: "live" })])
        .map((r) => r.sub || "").join(","), "live,");
      t.eq("favorites first on the empty line", C.rootRows([app], "", {}, [], { favorites: [app] })[0].section, "Favorites");
      t.eq("and not again under it", C.rootRows([app], "", { Firefox: 3 }, [], { favorites: [app] })
        .filter((r) => r.key === "Firefox").length, 1);
      const acts = C.rowActions(Object.assign({}, app, { favorite: true, favAt: 0, favCount: 2 })).map((a) => a.id);
      t.eq("a favorite's actions follow return", acts.slice(0, 3).join(","), "go,dropFav,favDown");
      t.eq("a file can go to the trash", C.rowActions(file).slice(-1)[0].id, "trash");
      t.ok("todo is Cynosure's own word", C.aliasProblem("todo") !== "");
    }

    {
      // ── places (2026-11-02) ───────────────────────────────────────────────
      const pl = C.placeRows(["/home/test/Code"], [{ uri: "sftp://box/", name: "box", path: "" }],
        ["/home/test/Code/", "/home/test/Music/"], "", "/home/test");
      t.eq("bookmarks, network, often visited", pl.map((r) => r.section).join(","), "Bookmarks,Network,Often visited");
      t.eq("a bookmark is not again among the often visited", pl.filter((r) => r.path === "/home/test/Code").length, 1);
      t.has("a place not connected says so", pl[1].sub, "not connected");
      t.eq("found by its name", C.placeRows(["/home/test/Code"], [], [], "cod", "/home/test").length, 1);
      // a directory wears its glyph from the map (2026-11-05)
      const dg = (e) => (e.isDir ? "D:" : "F:") + e.name + "@" + e.path;
      const gpl = C.placeRows(["/home/test/Code"], [{ uri: "sftp://box/", name: "box", path: "" }], [], "", "/home/test", dg);
      t.eq("places through glyphFor, network kept", gpl.map((r) => r.glyph), ["D:Code@/home/test/Code", "\u{F0870}"]);
      t.eq("a match wears its file's glyph", C.contentRows("/home/test/a.py:3:x = 1", "/home/test", dg)[0].glyph, "F:a.py@/home/test/a.py");
      t.eq("no glyphOf, the plain one", C.contentRows("/home/test/a.py:3:x = 1", "/home/test")[0].glyph, "\uF15C");
      const pents = [{ id: "1", content: "/home/test/Videos/a.mp4", preview: "/home/test/Videos/a.mp4" },
        { id: "2", content: "~/Code/", preview: "~/Code/" }, { id: "3", content: "two words", preview: "two words" },
        { id: "4", content: "/x/y.txt", preview: "/x/y.txt" }];
      const pcl = C.clipRows(pents, [], [], "", true, null, null, 4,
        { pins: [{ id: "4", text: "/x/y.txt" }], glyphOf: dg, home: "/home/test" });
      t.eq("a path clip wears its file's glyph, a pin its pin, words the clip",
        pcl.map((r) => r.id + "=" + r.glyph), ["4=\uF08D", "1=F:a.mp4@/home/test/Videos/a.mp4", "2=D:Code@/home/test/Code", "3=\uF0EA"]);

      // ── window places (2026-11-02) ────────────────────────────────────────
      const mon = { x: 1080, y: 396, width: 2560, height: 1440, scale: 1, transform: 0, reserved: [0, 0, 0, 0] };
      t.eq("the left half, less the gaps", C.snapRect(mon, 10, "left"), { x: 1090, y: 406, w: 1265, h: 1420 });
      t.eq("the right half meets it a gap away", C.snapRect(mon, 10, "right").x, 1090 + 1270 + 5);
      t.eq("filled", C.snapRect(mon, 0, "max"), { x: 1080, y: 396, w: 2560, h: 1440 });
      const turned = { x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 3, reserved: [0, 0, 0, 44] };
      t.eq("a turned screen is tall, less its bar", C.snapRect(turned, 0, "max"), { x: 0, y: 0, w: 1080, h: 1876 });
      t.eq("a size, centered", C.snapRect(mon, 0, "size", { w: 800, h: 600 }), { x: 1080 + 880, y: 396 + 420, w: 800, h: 600 });
      // thirds, quarters, larger (2026-11-03): no gaps, so the sums are plain
      t.eq("thirds", ["left3", "center3", "right3"].map((w) => C.snapRect(mon, 0, w).x - 1080), [0, 853, 1707]);
      t.eq("two thirds", C.snapRect(mon, 0, "right23"), { x: 1080 + 853, y: 396, w: 1707, h: 1440 });
      t.eq("a quarter", C.snapRect(mon, 0, "br"), { x: 1080 + 1280, y: 396 + 720, w: 1280, h: 720 });
      t.eq("thirds share the gaps", C.snapRect(mon, 10, "center3").x - C.snapRect(mon, 10, "left3").x - C.snapRect(mon, 10, "left3").w, 10);
      const win = { x: 1080 + 100, y: 396 + 100, w: 1000, h: 500 };
      t.eq("a tenth larger about its middle", C.snapRect(mon, 0, "grow", win), { x: 1130, y: 471, w: 1100, h: 550 });
      t.eq("larger stays on the screen", C.snapRect(mon, 0, "grow", { x: 1080, y: 396, w: 2560, h: 1440 }), { x: 1080, y: 396, w: 2560, h: 1440 });
      t.eq("as wide as there is room", C.snapRect(mon, 0, "maxW", win), { x: 1080, y: 496, w: 2560, h: 500 });
      t.eq("centered at its size", C.snapRect(mon, 0, "center", { w: 1000, h: 500 }), { x: 1080 + 780, y: 396 + 470, w: 1000, h: 500 });
      // the clipboard's filters, pins and turn (2026-11-03)
      const cents = [{ id: "3", content: "https://a.b/c", preview: "https://a.b/c" }, { id: "2", content: "#ff8800", preview: "#ff8800" },
        { id: "1", content: "plain words", preview: "plain words" }];
      t.eq("cb links", C.clipRows(cents, [], [], "links", true, null, null, 4, {}).map((r) => r.id), ["3"]);
      t.eq("cb colors", C.clipRows(cents, [], [], "colors", true, null, null, 4, {}).map((r) => r.id), ["2"]);
      const pinned = C.clipRows(cents, [], [], "", true, null, null, 4, { pins: [{ id: "1", text: "plain words" }, { id: "9", text: "gone now" }] });
      t.eq("pins lead, one cliphist let go from its words", pinned.slice(0, 2).map((r) => [r.section, r.label, r.gone]),
        [["Pinned", "plain words", false], ["Pinned", "gone now", true]]);
      t.eq("a pin not again below", pinned.filter((r) => r.id === "1").length, 1);
      t.eq("cb pinned is the pins alone", C.clipRows(cents, [], [], "pinned", true, null, null, 4, { pins: [{ id: "2", text: "#ff8800" }] }).map((r) => r.id), ["2"]);
      t.has("marked in turn", C.clipRows(cents, [], [], "", true, null, null, 4, { turn: ["2"] }).find((r) => r.id === "2").sub, "In turn 1");
      // quick links filled from the desk
      t.eq("{clipboard} filled, escaped", C.fillLinkFrom("https://x.com/?q={clipboard}&s={selection}", "a b", "c&d"), "https://x.com/?q=a%20b&s=c%26d");
      t.eq("a link of the clipboard alone opens as it is", C.linkUrl({ url: "https://x.com/{clipboard}" }, ""), "https://x.com/{clipboard}");
      t.eq("every new word is in the help", ["focus", "layout", "bm", "browsed", "github", "music", "menu", "qr", "ocr", "restart", "empty trash"]
        .filter((w) => !C.helpRows(w, {}).some((r) => r.cap === w || r.cap.indexOf(w) === 0)), []);
      t.eq("gaps as a number", C.gapsOf('{"option":"general:gaps_out","int":20}'), 20);
      t.eq("gaps as css", C.gapsOf('{"option":"general:gaps_out","custom":"12 12 12 12"}'), 12);

      // ── processes and ports (2026-11-02) ──────────────────────────────────
      const ps = C.processRows("  101  12.5  204800 firefox /usr/lib/firefox/firefox\n  7 0.0 1024 cynosure-self x\n", "", 7);
      t.eq("a process a row, not ourselves", ps.length, 1);
      t.has("with its CPU and memory", ps[0].sub, "12.5% CPU");
      t.has("in megabytes", ps[0].sub, "200 MB");
      t.eq("found by pid", C.processRows("  101  1  1 firefox x\n", "101", 0).length, 1);
      const ss = 'tcp   LISTEN 0 4096 127.0.0.1:8080 0.0.0.0:* users:(("node",pid=4242,fd=20))\n'
        + 'tcp   LISTEN 0 4096 [::1]:8080 [::]:* users:(("node",pid=4242,fd=21))\n'
        + 'tcp   LISTEN 0 4096 0.0.0.0:80800 0.0.0.0:*\n';
      const pr = C.portRows(ss, "8080");
      t.eq("one row a process and protocol", pr.length, 1);
      t.eq("its pid", pr[0].pid, 4242);

      // ── radios, repositories, services, notifications (2026-11-02) ────────
      t.eq("an unnamed device is left out", C.deviceRows([{ name: "AA:BB", named: false }, { name: "Buds", named: true,
        connected: true, paired: true, battery: 80, glyph: "" }], "").length, 1);
      t.has("a device says its battery", C.deviceRows([{ name: "Buds", named: true, connected: true, paired: true,
        battery: 80, glyph: "" }], "")[0].sub, "80% battery");
      t.eq("a network found by name", C.networkRows([{ name: "Home" }, { name: "Cafe" }], "ca")[0].label, "Cafe");
      const st = C.repoStatus("\u001e/r\n# branch.head main\n# branch.ab +2 -0\n1 .M N... x\n? y\n\u001e/gone\n");
      t.eq("branch", st["/r"].branch, "main");
      t.eq("changed", st["/r"].changed, 2);
      t.eq("ahead", st["/r"].ahead, 2);
      t.ok("gone is not ok", !st["/gone"].ok);
      t.has("a repository row says it", C.repoRows([{ root: "/r", name: "r" }], st, "", "/home/test")[0].sub, "2 to push");
      const sv = C.serviceRows([{ unit: "a.service", scope: "system", active: "active", sub: "running" },
        { unit: "b.service", scope: "user", active: "failed" }], "");
      t.eq("the failed first", sv[0].label, "b");
      t.has("yours says so", sv[0].sub, "yours");
      const nt = C.notifRows([{ id: 1, time: 1000, appName: "a", summary: "old", body: "" },
        { id: 2, time: 5000, appName: "b", summary: "<b>new</b>", body: "hi" }], "", new Date(65000));
      t.eq("the newest first, markup gone", nt[0].label, "new");
      t.has("how long ago", nt[0].sub, "1 min ago");

      // ── clipboard transforms (2026-11-02) ─────────────────────────────────
      t.eq("title case", C.transformText("title", "hello wide world"), "Hello Wide World");
      // no \p{L} (QV4 matches nothing with it); after a bracket too
      t.eq("title case, accents and brackets", C.transformText("title", "ÉLAN ça-va (x)"), "Élan Ça-Va (X)");
      t.eq("slug", C.transformText("slug", "Héllo, World!"), "hello-world");
      t.eq("sorted", C.transformText("sort", "b\nA\n\nc"), "A\nb\nc");
      t.eq("pretty json", C.transformText("json", '{"a":1}'), '{\n  "a": 1\n}');
      t.eq("not json", C.transformText("json", "nope"), null);
      t.eq("base64", C.transformText("b64", "hi"), "aGk=");
      t.ok("a text clip offers them", C.rowActions({ kind: "clip", label: "x" }).some((a) => a.id === "as:upper"));
    }

    {
      // ── list and inline scripts (2026-11-02) ──────────────────────────────
      t.eq("30s", C.refreshMs("30s"), 30000);
      t.eq("5m", C.refreshMs("5 min"), 300000);
      t.eq("a bare number is seconds", C.refreshMs("2"), 2000);
      t.eq("not under a second", C.refreshMs("0.1"), 1000);
      t.eq("nothing", C.refreshMs(""), 0);
      const scs = C.parseScripts("\u001e/s/gh.sh\n# @mode list\n# @word gh\n\u001e/s/cpu.sh\n# @mode inline\n# @refresh 10s\n");
      t.eq("list mode is kept", scs[0].mode, "list");
      t.eq("refresh is read", scs[1].refresh, 10000);
      t.eq("a list script's word and a space", C.scriptListFor(scs, "gh issues").arg, "issues");
      t.eq("its word alone is not yet", C.scriptListFor(scs, "gh"), null);
      t.eq("a list script types its word", C.scriptActions(scs, {})[0].line, "gh ");
      t.eq("an inline one wears what it said", C.scriptActions(scs, { "/s/cpu.sh": "42%\nmore" })[1].sub, "42%");
      t.eq("json array", C.parseListItems('[{"title":"a","open":"https://x"}]')[0].open, "https://x");
      t.eq("json items", C.parseListItems('{"items":[{"title":"a"},{"title":"b"}]}').length, 2);
      t.eq("json lines", C.parseListItems('{"title":"a"}\n{"title":"b","copy":"B"}')[1].copy, "B");
      t.eq("plain lines copy themselves", C.parseListItems("one\ntwo")[1].copy, "two");
      t.eq("an item's verb", C.verbOf({ kind: "sitem", item: { open: "", paste: "x", run: "" } }), "paste");

      // ── inside files, fonts, captures (2026-11-02) ────────────────────────
      const hits = C.contentRows("/home/test/a.md:12:  the words\n/home/test/b:3:\n", "/home/test");
      t.eq("a line a row", hits.length, 2);
      t.eq("its line", hits[0].line, 12);
      t.eq("said where", hits[0].sub, "~/a.md:12");
      t.has("the search quotes the words", C.contentCommand("it's", "/h"), "'it'\\''s'");
      const fams = [{ name: "Inter", variants: ["Inter"], styles: [1, 2], files: ["/f"], mono: false, nerd: false, user: true },
        { name: "JetBrains Mono", variants: ["JetBrainsMono NF"], styles: [1], files: ["/g"], mono: true, nerd: true, user: false }];
      t.eq("found by name", C.fontRows(fams, "jet", 4)[0].cells[0].face, "JetBrainsMono NF");
      t.has("says what it is", C.fontRows(fams, "jet", 4)[0].cells[0].sub, "monospace");
      t.eq("a grid, so many a row", C.fontRows(fams, "", 1).length, 2);
      const cap = C.captureRows("1762000000\t/p/Screenshots/a.png\n1761000000\t/p/Screenshots/b.png\n",
        "", { "/p/Screenshots/a.png": "/t/a.png", "/p/Screenshots/b.png": "-" }, 4, false);
      t.eq("one row of cells", cap.length, 1);
      t.eq("a thumbnail", cap[0].cells[0].thumb, "/t/a.png");
      t.eq("a picture with alpha is its own thumbnail", cap[0].cells[1].thumb, "/p/Screenshots/b.png");
      t.eq("found by name", C.captureRows("1\t/p/x.png\n2\t/p/y.png\n", "y", {}, 4, false)[0].cells.length, 1);
    }

    {
      // ── help (2026-11-02) ─────────────────────────────────────────────────
      const all = C.helpRows("", {});
      t.ok("every group", ["Find", "Make", "Ask", "Do", "Keys"].every((g) => all.some((r) => r.section === g)));
      t.ok("every scope word is in it", ["f", "in", "go", "win", "cb", "notes", "todos", "book", "font", "shots", "rec",
        "colors", "notif", "settings", "store", "pkg", "repo", "svc", "ps", "port", "output", "bt", "wifi", "em", "nf",
        "pw", "note", "todo", "event"].every((w) => all.some((r) => r.cap === w)));
      t.eq("found by its words", C.helpRows("weather", {})[0].cap, "weather");
      t.eq("return types the word", C.helpRows("bluetooth devices", {})[0].fill, "bt ");
      const own = C.helpRows("", { aliases: { ff: { label: "Firefox" } }, links: [{ word: "g", name: "Google" }],
        scripts: [{ word: "wx", title: "Weather", argument: "a city", mode: "silent" }] });
      t.ok("your words, links and scripts", ["Your words", "Quick links", "Your scripts"].every((g) => own.some((r) => r.section === g)));
      t.ok("a key is only said", C.rowActions(C.helpRows("shift return", {})[0]).length === 0);
    }

    // ── markup ────────────────────────────────────────────────────────────
    // The rows are StyledText, so a name with an ampersand in it must not
    // become half a markup entity.
    t.eq("an ampersand is escaped", C.escMarkup("a & b"), "a &amp; b");
    t.eq("the match is underlined where it matched",
      C.highlight("firefox", "fire"), "<u>fire</u>fox");
    t.eq("no query means no markup", C.highlight("firefox", ""), "firefox");
    // contacts and light and dark (2026-11-03)
    const ids = (r) => C.rowActions(r).map((x) => x.id);
    t.eq("a contact with mail writes", ids({ kind: "contact", label: "Ada", email: "a@b.c", phone: "1", path: "/x.vcf" }),
      ["go", "copyEmail", "copyPhone", "copyName", "reveal"]);
    t.eq("a contact with a number only copies it", ids({ kind: "contact", label: "Ada", email: "", phone: "1", path: "" }), ["go", "copyName"]);
    const opts = [{ value: "zenon" }, { value: "zenon-light", light: true }, { value: "rose-pine" }, { value: "rose-pine-dawn", light: true },
      { value: "gruvbox-dark" }, { value: "gruvbox-light", light: true },
      { value: "monochrome-dark" }, { value: "monochrome-light", light: true }];
    t.eq("light: the pair", C.themeSide("rose-pine", true, opts), "rose-pine-dawn");
    t.eq("dark: the pair back", C.themeSide("rose-pine-dawn", false, opts), "rose-pine");
    t.eq("light: a name swap", C.themeSide("gruvbox-dark", true, opts), "gruvbox-light");
    t.eq("monochrome both ways", [C.themeSide("monochrome-dark", true, opts), C.themeSide("monochrome-light", false, opts)],
      ["monochrome-light", "monochrome-dark"]);
    t.eq("already light", C.themeSide("zenon-light", true, opts), null);
    t.eq("no partner, Zenon's", C.themeSide("mystery", true, opts), "zenon-light");
    // Oracle's Cynosure › Search (2026-11-03)
    const web = (e) => C.allLinks([], e).find((l) => l.word === "web").url;
    t.eq("web search goes where it is set", [web("google"), web("kagi"), web("nope")],
      ["https://www.google.com/search?q={q}", "https://kagi.com/search?q={q}", "https://duckduckgo.com/?q={q}"]);
    t.eq("your own web link wins", C.allLinks([{ word: "web", url: "https://x.y/?q={q}" }], "google").filter((l) => l.word === "web").map((l) => l.url),
      ["https://x.y/?q={q}"]);
    const few = [{ kind: "app", key: "a", text: "Alpha", label: "Alpha" }, { kind: "app", key: "b", text: "Beta", label: "Beta" },
      { kind: "hist", key: "h", text: "alpha --x", label: "alpha --x" }];
    const sections = (rows) => rows.map((r) => r.section);
    t.eq("no suggestions", sections(C.rootRows(few, "", { a: 3 }, [], { suggested: 0 })).indexOf("Suggestions"), -1);
    t.eq("no history while not learning", C.rootRows(few, "", {}, [], { history: false }).some((r) => r.kind === "hist"), false);
    t.eq("no other ways", C.rootRows(few, "alp", {}, [], { fallbacks: false }).some((r) => r.kind === "fallback" || r.kind === "run"), false);
    t.eq("other ways by default", C.rootRows(few, "alp", {}, [], {}).some((r) => r.kind === "run"), true);
    // hidden, the fallbacks' order (2026-11-04)
    const hid = C.withHidden("", "app:b", "Beta", true);
    t.eq("hidden: kept with its name", C.parseHidden(hid), [{ id: "app:b", name: "Beta" }]);
    t.eq("hidden: put back", C.withHidden(hid, "app:b", "", false), "");
    t.eq("a hidden app is gone from the list", C.rootRows(few, "beta", {}, [], { hidden: C.hiddenSet(hid) }).some((r) => r.key === "b"), false);
    t.ok("a hidden app can be hidden, a clip cannot", C.rowActions({ kind: "app", key: "a", label: "A" }).some((x) => x.id === "hide")
      && !C.rowActions({ kind: "clip", id: "1", label: "x" }).some((x) => x.id === "hide"));
    t.eq("fallbacks: the usual order, all on", C.fallbackList("").map((f) => f.word).slice(0, 3), ["web", "f", "cb"]);
    t.eq("fallbacks: moved up", C.fallbackList(C.fallbackMoved("", "f", -1)).map((f) => f.word).slice(0, 2), ["f", "web"]);
    t.eq("fallbacks: the first goes no higher", C.fallbackMoved("", "web", -1), C.fallbackText(C.fallbackList("")));
    t.eq("fallbacks: one off", C.fallbackList(C.fallbackSet("", "pkg", false)).find((f) => f.word === "pkg").on, false);
    t.eq("fallbacks: an unknown word dropped, a new one on at the end",
      C.fallbackList("nope,tr").map((f) => f.word).slice(0, 2), ["tr", "web"]);
    const order = (text) => C.rootRows(few, "zzz", {}, [], { fallbackList: text, links: C.allLinks([], "") }).filter((r) => r.fbWord).map((r) => r.fbWord);
    t.eq("the list follows your order", order("tr,web").slice(0, 2), ["tr", "web"]);
    t.eq("one turned off is not offered", order("-web").indexOf("web"), -1);
    // a quick link in its own browser
    const ghLink = C.withLinkApp([], "gh", "brave.desktop", "Brave");
    t.eq("a built-in kept for its app only", ghLink.map((l) => [l.word, l.builtin, l.app]), [["gh", true, "brave.desktop"]]);
    t.eq("it opens there, the built-in under it", (C.allLinks(ghLink, "duckduckgo").find((l) => l.word === "gh") || {}).app, "brave.desktop");
    t.eq("back to the default browser drops the stand-in", C.withLinkApp(ghLink, "gh", "", ""), []);
    t.eq("your own link changed in place", C.withLinkApp([{ word: "x", url: "https://x.y" }], "x", "f.desktop", "F")[0].app, "f.desktop");
    t.eq("browsers from grep -H", C.parseBrowsers("/usr/share/applications/firefox.desktop:Name=Firefox\n/a/firefox.desktop:Name=Again"),
      [{ id: "firefox", name: "Firefox" }]);
    t.ok("a stand-in cannot be removed as a link", !C.rowActions(C.allLinks(ghLink, "")
      .filter((l) => l.word === "gh").map((l) => ({ kind: "link", own: l.own, builtin: l.builtin, url: l.url }))[0]).some((x) => x.id === "dropLink"));
    // chips (2026-11-04)
    t.eq("def is the dictionary's chip", C.chipFor("define", [], []), { word: "def", text: "Dictionary" });
    t.eq("a quick link is a chip", C.chipFor("gh", [{ word: "gh", name: "GitHub" }], []), { word: "gh", text: "GitHub" });
    t.eq("a plain word is not", C.chipFor("firefox", [], []), null);
    t.eq("a begun word, one chip", (C.chipComplete("lay", [], []) || {}).word, "layout");
    t.eq("a begun word, two chips: none", C.chipComplete("wi", [], []), null);
    t.eq("one letter: none", C.chipComplete("q", [], []), null);
    // short sections, related chips, a chip's last searches (2026-11-04)
    const manyFiles = [1, 2, 3, 4, 5, 6].map((i) => ({ kind: "file", key: "f" + i, path: "/x/a" + i, text: "a" + i, label: "a" + i }));
    const capped = C.rootRows([], "zz", {}, C.SHELL_ACTIONS, { files: manyFiles, fallbacks: false });
    t.eq("a long section keeps three and a row for the rest", capped.map((r) => r.kind + ":" + (r.label || "")),
      ["file:a1", "file:a2", "file:a3", "more:3 more files"]);
    t.eq("the row opens it as its chip", capped[3].line, "f zz");
    t.eq("one past the cap is shown whole", C.rootRows([], "zz", {}, C.SHELL_ACTIONS,
      { files: manyFiles.slice(0, 4), fallbacks: false }).length, 4);
    t.eq("under a chip, every one", C.rootRows([], "f zz", {}, C.SHELL_ACTIONS,
      { files: manyFiles, filesOnly: true }).length, 6);
    t.eq("the cap can be turned off", C.rootRows([], "zz", {}, C.SHELL_ACTIONS,
      { files: manyFiles, fallbacks: false, sectionCap: false }).length, 6);
    t.eq("windows, then snap", C.chipNext("win", false), { word: "snap", text: "Snap" });
    t.eq("layouts round to windows", C.chipNext("layout", false).word, "win");
    t.eq("shift tab goes back", C.chipNext("win", true).word, "layout");
    t.eq("a chip in no ring stays", C.chipNext("help", false), null);
    t.eq("a chip's last searches, its own only, newest first",
      C.chipRecentRows(["todos milk", "win docs", "tasks bread", "todos milk", "todos ", "todos a", "todos b"], "todos", [], [])
        .map((r) => r.label + "|" + r.text), ["milk|todos milk", "bread|todos bread", "a|todos a"]);
    t.eq("a card with its own recents chips has no list of them",
      ["def", "tr", "calc"].map((w) => C.chipRecentRows([w + " cat", "define dog", "translate hi"], w, [], []).length), [0, 0, 0]);
    const openWins = [{ address: "0x1", app: "firefox", title: "Docs" }, { address: "0x2", app: "firefox", title: "Mail" },
      { address: "0x3", app: "kitty", title: "zsh" }, { address: "0x4", app: "org.quickshell", title: "oracle" }];
    const quits = C.quitRows(openWins, "", null, (id) => id === "firefox" ? "Firefox" : "");
    t.eq("one row an app, not ours", quits.map((r) => r.label + "|" + r.sub), ["Quit Firefox|2 windows", "Quit kitty|zsh"]);
    t.eq("filtered by name or title", C.quitRows(openWins, "mail", null, null).map((r) => r.cmd.app), ["firefox"]);
    const trayed = C.quitRows(openWins, "", null, null, [{ pid: 9, comm: "steam", classes: [] }, { pid: 7, comm: "firefox-bin", classes: ["firefox"] }]);
    t.eq("a tray app with no window is one too, one open is not twice", trayed.map((r) => r.cmd.kind + ":" + r.text),
      ["quitApp:firefox", "quitApp:kitty", "quitTray:Steam"]);
    t.eq("quitting a windowed app ends its tray process too", trayed[0].cmd.pids, [7]);
    t.eq("never the shell itself", C.quitRows([], "", null, null, [{ pid: 9, comm: "quickshell", classes: [] },
      { pid: 8, comm: ".quickshell-wra", classes: [] }, { pid: 6, comm: "Hyprland", classes: [] }]), []);
    t.eq("a whole alias over a pick", C.topRows([{ kind: "app", key: "a", text: "Alpha", alias: "zz" },
      { kind: "app", key: "b", text: "zzbeta" }], [], "zz", {}, {}, { zz: { b: 5 } })[0].key, "a");
    t.eq("a process named as an app", C.trayName("claude-desktop"), "Claude");
    t.eq("snap: every place, filtered by its name or words", C.snapRows("third", "x").map((r) => r.cmd.where),
      ["left3", "center3", "right3", "left23", "right23"]);
    t.eq("snap: all of them", C.snapRows("", "").length, 24);
    const themes = [{ value: "zenon", label: "Zenon" }, { value: "nord", label: "Nord" }, { value: "ayu-light", label: "Ayu Light  \u{F19E2}" }];
    t.eq("theme: filtered by name, the worn one marked", C.themeRows(themes, "nord", "nor", null).map((r) => [r.cmd.value, r.worn]),
      [["nord", true]]);
    t.eq("theme: every row says Theme, the worn one too (it is dimmed)", C.kindName(C.themeRows(themes, "nord", "", null)[1]), "Theme");
    t.eq("theme: is a chip", C.chipFor("themes").word, "theme");
    // what you pick for what you type; looser matching (2026-11-04)
    const apps2 = [{ kind: "app", key: "bash", text: "Bash" }, { kind: "app", key: "brave", text: "Brave Origin" },
      { kind: "app", key: "vsc", text: "Visual Studio Code" }, { kind: "app", key: "ff", text: "Firefox" }];
    t.eq("unpicked: the plain order", C.rankRows(apps2, "b").map((r) => r.key).slice(0, 2), ["bash", "brave"]);
    const picked = C.notePick({}, "bra", "brave");
    t.eq("a pick teaches its starts", Object.keys(picked), ["br", "bra"]);
    t.eq("picked: first for that line", C.rankRows(apps2, "br", picked)[0].key, "brave");
    t.eq("and first of the top results", C.topRows(C.rankRows(apps2, "br", picked), [], "br", {}, {}, picked)[0].key, "brave");
    t.eq("first letters", C.rankRows(apps2, "vsc").map((r) => r.key), ["vsc"]);
    t.eq("letters in order", C.rankRows(apps2, "frfx").map((r) => r.key), ["ff"]);
    t.eq("one slip", C.rankRows(apps2, "fierfox").map((r) => r.key), ["ff"]);
    t.eq("two slips: nothing", C.rankRows(apps2, "fxerfoz").length, 0);
    t.eq("a plain match outranks a loose one", C.rankRows([{ kind: "app", key: "a", text: "Frfx" }].concat(apps2), "frfx")[0].key, "a");
    let many = {};
    for (let i = 0; i < 450; i++) many = C.notePick(many, "q" + i, "k");
    t.ok("picks are capped", Object.keys(many).length <= 400);
    t.eq("no layouts: says so", C.layoutRows({}, "").map((r) => r.kind), ["info"]);
    t.eq("history: your searches, filtered", C.searchRows(["def apple", "win code", "def pear"], "def").map((r) => r.text), ["def apple", "def pear"]);
    // what was searched, not what was typed (2026-11-07)
    t.eq("history: the start typed becomes the app picked", C.pickedLine("cla", "", { kind: "app", label: "Claude" }), "Claude");
    t.eq("history: a theme under its chip, its marks dropped",
      C.pickedLine("theme ", "theme", { kind: "argcmd", cmd: { kind: "theme" }, label: "Ayu Light  \u{F19E2}" }), "theme Ayu Light");
    t.eq("history: a clip's text is never kept", C.pickedLine("cb pass", "cb", { kind: "clip", label: "hunter2" }), "cb pass");
    t.eq("history: no row, the line", C.pickedLine(" def apple ", "def", null), "def apple");
    const e = C.queryEntry("Claude", { glyph: "", text: "App" });
    t.eq("history: an entry keeps its chip", [C.queryText(e), C.queryTag(e).text], ["Claude", "App"]);
    t.eq("history: once, by its line", C.addQuery([C.queryEntry("Claude", { text: "App" })], "Claude").length, 1);
    const hist = C.searchRows(["def apple\t\uF02D\tDictionary", "Claude\t\tApp", "plain"], "", [], []);
    t.eq("history: chip and rest, a tag, or nothing",
      hist.map((r) => [r.label, r.chipTag ? r.chipTag.text : null, r.text]),
      [["apple", "Dictionary", "def apple"], ["Claude", "App", "Claude"], ["plain", null, "plain"]]);
    t.eq("recents under a chip read a tagged entry", C.chipRecentRows(["f invoice\t\uF114\tFiles"], "f").map((r) => r.label), ["invoice"]);
    t.eq("layouts listed, the line saved as a new one",
      C.layoutRows({ coding: [1, 2], games: [1] }, "co").map((r) => r.cmd.kind + ":" + r.cmd.name), ["layoutUse:coding", "layoutSave:co"]);
    t.eq("an exact name is not saved again", C.layoutRows({ coding: [1] }, "coding").length, 1);
    // skin tones: folded onto the base, shown in the one chosen
    const em = C.Ideo.parseEmojiTest("1F44B ; fully-qualified # \u{1F44B} E0.6 waving hand\n"
      + "1F44B 1F3FB ; fully-qualified # \u{1F44B}\u{1F3FB} E1.0 waving hand: light skin tone\n"
      + "1F9D1 1F3FB 200D 1F91D 200D 1F9D1 1F3FF ; fully-qualified # x E12.0 people holding hands: light skin tone, dark skin tone\n");
    t.eq("one entry, its tones on it", em.map((e) => e.name), ["waving hand"]);
    t.eq("the chosen tone shown", C.glyphRows(em, "wav", false, false, 14, [], "light")[0].cells[0].char, "\u{1F44B}\u{1F3FB}");
    t.eq("no tone set, its own yellow", C.glyphRows(em, "wav", false, false, 14, [], "none")[0].cells[0].char, "\u{1F44B}");
  }
};
