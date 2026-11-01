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
      mode: "silent", argument: "", word: "restart-waybar", keywords: "" });
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

    // ── markup ────────────────────────────────────────────────────────────
    // The rows are StyledText, so a name with an ampersand in it must not
    // become half a markup entity.
    t.eq("an ampersand is escaped", C.escMarkup("a & b"), "a &amp; b");
    t.eq("the match is underlined where it matched",
      C.highlight("firefox", "fire"), "<u>fire</u>fox");
    t.eq("no query means no markup", C.highlight("firefox", ""), "firefox");
  }
};
