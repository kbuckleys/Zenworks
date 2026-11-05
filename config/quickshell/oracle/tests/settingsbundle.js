// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// oracle's settings export/import: what a bundle may hold and nothing else.

"use strict";

module.exports = {
  module: "oracle/oracle.js",
  cases: (O, t) => {
    t.eq("a theme lands only over nothing or your own", [null, "", "{\"custom\":true}", "{\"name\":\"Dracula\"}", "not json"].map(O.bundleThemeWritable),
      [true, true, true, false, false]);
    t.eq("allowed", ["oracle.json", "hypr/keys.lua", "themes/my-theme.json"].map(O.bundlePathOk), [true, true, true]);
    t.eq("refused", ["hypr/binds.lua", "themes/../x.json", "/etc/passwd", "themes/.hidden.json", "../oracle.json"].map(O.bundlePathOk),
      [false, false, false, false, false]);
    const text = O.makeBundle({ "oracle.json": "{}", "hypr/keys.lua": "return {}", "evil/../x": "no" }, "2026-10-21");
    const back = O.readBundle(text);
    t.eq("round trip", [back.ok, Object.keys(back.files).sort(), back.made], [true, ["hypr/keys.lua", "oracle.json"], "2026-10-21"]);
    const sneaky = O.readBundle(JSON.stringify({ zenworks: "settings", files: { "oracle.json": "{}", "../../.bashrc": "rm -rf ~" } }));
    t.eq("a path outside is dropped", [Object.keys(sneaky.files), sneaky.skipped], [["oracle.json"], 1]);
    t.eq("not ours", O.readBundle('{"hello":1}').ok, false);
    t.eq("empty", O.readBundle('{"zenworks":"settings","files":{}}').why, "There are no settings in it");
    t.eq("words", O.bundleWords({ "themes/b.json": "", "hypr/monitors.lua": "", "oracle.json": "" }),
      ["Settings", "Screen arrangement", "Theme b"]);

    // ── an import writes values, never the Lua it came with ──
    // hyprland `require`s these files: code in one would run at the reload
    const evil = "os.execute(\"touch /tmp/pwned\")\nlocal p = io.popen(\"id\")\n";
    const lua = ["hypr/keys.lua", "hypr/wake.lua", "hypr/effects.lua", "hypr/defaults.lua",
                 "hypr/input.lua", "hypr/windows.lua", "hypr/startup.lua", "hypr/monitors.lua"];
    const code = (s) => /os\.execute|io\.popen|require|dofile|loadstring|\bload\s*\(/.test(s);
    t.eq("no code survives in any file", lua.filter((rel) =>
      code(O.sanitizeBundleFile(rel, evil + "return {\n\tterminal = \"kitty\",\n}\n" + evil, []))), []);
    t.eq("what is not Lua passes as it is", O.sanitizeBundleFile("oracle.json", "{\"a\":1}"), "{\"a\":1}");
    // nor out of a string: a quote, a backslash or a line break stays inside it
    const trick = "x\") os.execute(\"y\\";
    const st = O.sanitizeBundleFile("hypr/startup.lua", O.renderStartupLua([{ name: "a", command: trick }]));
    t.eq("a quote in a command stays in its string", O.parseStartupLua(st).map((a) => a.command), [trick]);
    t.ok("a line break is written escaped", O.luaString("a\nos.execute()").indexOf("\n") < 0);
    // the values themselves come through
    const keys = O.sanitizeBundleFile("hypr/keys.lua", "return {\n\tterm = \"SUPER + T\",\n\tgone = \"\",\n}\n",
      [{ id: "term", chord: "SUPER + RETURN" }, { id: "gone", chord: "SUPER + G" }, { id: "same", chord: "SUPER + S" }]);
    t.eq("shortcuts kept, by binds.lua's ids", O.parseDefaultsLua(keys), { term: "SUPER + T", gone: "" });
    t.eq("with no list, every one named", O.parseDefaultsLua(O.sanitizeBundleFile("hypr/keys.lua", "return { a = \"SUPER + A\" }")),
      { a: "SUPER + A" });
    t.eq("wake and effects", [O.parseWakeLua(O.sanitizeBundleFile("hypr/wake.lua", "return { wake = \"key\" }")),
      O.parseEffectsLua(O.sanitizeBundleFile("hypr/effects.lua", "return { shadows = false }"))].map((x) =>
        typeof x === "string" ? x : { shadows: x.shadows, animations: x.animations }),
      ["key", { shadows: false, animations: true }]);
    t.eq("default apps, hand-written ones too", O.parseDefaultsLua(O.sanitizeBundleFile("hypr/defaults.lua",
      "return { terminal = \"foot\", mine = \"x.desktop\" }")).mine, "x.desktop");
    t.eq("input", O.parseInputLua(O.sanitizeBundleFile("hypr/input.lua", "return { kb_layout = \"us,de\", sensitivity = -0.5 }")).sensitivity, -0.5);
    const wr = O.normWindowRule({ class: "firefox", float: true, size: "1200 800" });
    t.eq("window rules", O.parseWindowsLua(O.sanitizeBundleFile("hypr/windows.lua", O.renderWindowsLua([wr]))), [wr]);
    const mon = O.sanitizeBundleFile("hypr/monitors.lua",
      "hl.monitor({ output = \"\", mode = \"preferred\" })\nhl.monitor({ output = \"desc:LG 27\", mode = \"2560x1440@144\", scale = 1.25, vrr = 1.2.3 })\nhl.workspace_rule({})\n");
    t.eq("screens: one catch-all, the rule kept, a bad number dropped", O.parseMonitorRules(mon),
      [{ output: "", fields: { mode: "preferred", position: "auto", scale: "auto" } },
       { output: "desc:LG 27", fields: { mode: "2560x1440@144", scale: 1.25 } }]);
    t.ok("and nothing written by hand", mon.indexOf("workspace_rule") < 0);

    // ── what it would run, shown first ──
    t.eq("the commands it brings", O.bundleCommands({
      "hypr/startup.lua": O.renderStartupLua([{ name: "Discord", command: "discord --start-minimized" }, { name: "", command: "x", on: false }]),
      "hypr/defaults.lua": "return { terminal = \"kitty\", editor = \"\", sysmon = \"zeus\", browser = \"firefox.desktop\" }"
    }), [{ what: "At login · Discord", command: "discord --start-minimized", off: false },
         { what: "At login", command: "x", off: true },
         { what: "Terminal", command: "kitty", off: false }]);
    t.eq("none", O.bundleCommands({ "oracle.json": "{}" }), []);
    // every app's own choices (2026-11-03)
    t.eq("an app's file may come", ["apps/terminus-view.json", "apps/cynosure-links.json", "apps/terminus-bookmarks"].map(O.bundlePathOk), [true, true, true]);
    t.eq("but not one unnamed", ["apps/howler-history.json", "apps/../oracle.json", "apps/usage.json"].map(O.bundlePathOk), [false, false, false]);
    t.eq("only an app's settings go", JSON.parse(O.appSettingsOf("apps/calypso.json",
      '{"accounts":[{"email":"a@b"}],"lockAfter":5,"recent":["x"],"sort":"name"}')), { sort: "name", lockAfter: 5 });
    t.eq("a file of no settings is nothing", O.appSettingsOf("apps/calypso.json", '{"accounts":[]}'), "");
    t.eq("not JSON is nothing", O.appSettingsOf("apps/terminus-view.json", "{"), "");
    t.eq("laid over what is here, the rest kept", JSON.parse(O.appSettingsInto("apps/calypso.json", '{"lockAfter":9,"accounts":["evil"]}',
      '{"accounts":["mine"],"lockAfter":5}')), { accounts: ["mine"], lockAfter: 9 });
    t.eq("a whole file replaces", JSON.parse(O.appSettingsInto("apps/cynosure-links.json", '[{"word":"gh"}]', '[{"word":"old"}]')), [{ word: "gh" }]);
    t.eq("lines keep only lines", O.appSettingsOf("apps/terminus-bookmarks", "/home/a\n\n/home/b\u0007\n/srv"), "/home/a\n/srv\n");
    t.eq("said on the sheet", O.bundleWords({ "oracle.json": "{}", "apps/terminus-view.json": "{}" }), ["Settings", "Terminus"]);
    t.eq("an app's sanitized as data", O.sanitizeBundleFile("apps/stylus.json", '{"sidebar":true,"x":1}'), '{"sidebar":true}');
    // the hyper key
    t.has("hyper.lua names its keymap", O.renderHyperLua("/h/hyper.xkb", "caps", "us|||"), 'file = "/h/hyper.xkb"');
    t.has("none, none", O.renderHyperLua("", "caps", "x"), 'key  = "off"');
    t.eq("Hyper is the four", O.normChord("hyper + t"), "SUPER + SHIFT + CONTROL + ALT + T");
    t.eq("and is drawn as one cap", O.chordCaps("SUPER + SHIFT + CONTROL + ALT + T"), ["Hyper", "T"]);
    t.eq("three is not Hyper", O.chordCaps("SUPER + SHIFT + ALT + T"), ["Super", "Shift", "Alt", "T"]);
  }
};
