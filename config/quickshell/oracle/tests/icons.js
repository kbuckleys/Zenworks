// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┘┴ ┴└─┘
// https://github.com/kbuckleys/
//
// The glyph table, which is now terminus' own rather than a parse of somebody
// else's theme file — see the note at the top of icons.js. That change is
// exactly why this suite exists: the old arrangement could fail SILENTLY, by
// reading a file that was not there or not shaped the way the parser expected,
// and every file in the window came out as a blank page with nothing said. A
// table in the source cannot go missing, and a count that is asserted cannot
// quietly become zero.

"use strict";

module.exports = {
  module: "morpheus/icons.js",
  cases: (T, t) => {
    // ── precedence ────────────────────────────────────────────────────────
    // The most specific rule wins, which is the whole of the lookup order.
    t.eq("an exact filename beats its extension",
      T.glyphFor({ name: "Cargo.toml" }), T.glyphFor({ name: "main.rs" }));
    t.ok("and that is NOT what a plain .toml gets",
      T.glyphFor({ name: "other.toml" }) !== T.glyphFor({ name: "Cargo.toml" }));
    t.eq("an extension beats the catch-all",
      T.glyphFor({ name: "a.zst" }), T.glyphFor({ name: "b.tar" }));
    t.ok("and something nothing claims falls through to the plain page",
      T.glyphFor({ name: "x.qqzz" }) === T.glyphFor({ name: "y.wwvv" }));

    // A DIRECTORY is matched against the directory rules and never against the
    // extension ones: "src.old" is a directory, not an .old file.
    t.ok("a directory named like an extension is still a directory",
      T.glyphFor({ name: "src.old", isDir: true })
        !== T.glyphFor({ name: "src.old" }));
    // Ubisoft's launcher directories, by any of their names (2026-11-05)
    t.eq("Ubisoft's directories wear its glyph",
      ["Ubisoft", "Ubisoft Connect", "Ubisoft Game Launcher"].map((n) => T.glyphFor({ name: n, isDir: true })),
      ["\u{F0BDA}", "\u{F0BDA}", "\u{F0BDA}"]);
    t.eq("the game stores' directories wear theirs",
      [".minecraft", "GOG Games", "Battle.net", "itch", "EA Desktop", "Humble App", "SteamLibrary", "XboxGames"]
        .map((n) => T.glyphFor({ name: n, isDir: true })),
      ["\u{F0373}", "\u{F0BA1}", "\uEF94", "\uEF99", "\u{F0B43}", "\u{F0744}", "\uF1B7", "\u{F05B9}"]);
    t.eq("a directory nothing names gets the plain folder",
      T.glyphFor({ name: "zzqq", isDir: true }),
      T.glyphFor({ name: "wwvv", isDir: true }));

    // ── case ──────────────────────────────────────────────────────────────
    t.eq("MAKEFILE is makefile", T.glyphFor({ name: "MAKEFILE" }),
      T.glyphFor({ name: "makefile" }));
    t.eq("and so is Makefile", T.glyphFor({ name: "Makefile" }),
      T.glyphFor({ name: "makefile" }));
    t.eq("an extension is lowercased too", T.glyphFor({ name: "PHOTO.PNG" }),
      T.glyphFor({ name: "photo.png" }));

    // ── extensionOf ───────────────────────────────────────────────────────
    t.eq("the last dot wins", T.extensionOf("a.tar.gz"), "gz");
    t.eq("a leading dot is a hidden file, not an extension",
      T.extensionOf(".bashrc"), "");
    t.eq("nor is a trailing one", T.extensionOf("weird."), "");
    t.eq("no dot at all", T.extensionOf("Makefile"), "");
    t.eq("and it lowercases", T.extensionOf("IMAGE.PNG"), "png");

    // ── the states a file can be in ───────────────────────────────────────
    // Checked in order: a broken link is reported as broken before anything
    // else gets a say, because that is the fact that matters about it.
    t.ok("a broken link says so",
      T.glyphFor({ name: "a.rs", isLink: true, broken: true })
        !== T.glyphFor({ name: "a.rs" }));
    t.eq("a live link to a known type keeps the type's glyph",
      T.glyphFor({ name: "a.rs", isLink: true }), T.glyphFor({ name: "a.rs" }));
    t.ok("an executable nothing else claims is marked as one",
      T.glyphFor({ name: "runme", isExec: true })
        !== T.glyphFor({ name: "runme" }));
    // and the extension still outranks it: a .sh is a shell script whether or
    // not the bit happens to be set
    t.eq("an extension outranks the executable bit",
      T.glyphFor({ name: "go.sh", isExec: true }), T.glyphFor({ name: "go.sh" }));

    // ── names that are also Object's business ─────────────────────────────
    // A file called "constructor" is a file, not a lookup that comes back with
    // a function and renders as one.
    t.eq("a file called constructor is just a file",
      T.glyphFor({ name: "constructor" }), T.glyphFor({ name: "zzqqvv" }));
    t.eq("so is __proto__", T.glyphFor({ name: "__proto__" }),
      T.glyphFor({ name: "zzqqvv" }));
    t.eq("and a directory called toString",
      T.glyphFor({ name: "toString", isDir: true }),
      T.glyphFor({ name: "zzqqvv", isDir: true }));

    // ── nothing at all ────────────────────────────────────────────────────
    t.eq("no entry is not a crash", T.glyphFor(null), "");
    t.eq("nor is an entry with no name", T.glyphFor({}),
      T.glyphFor({ name: "zzqqvv" }));

    // ── the table is actually there ───────────────────────────────────────
    // The failure the old parse could produce was an EMPTY table and no error,
    // so this is the assertion that would have caught it.
    t.ok("the table is populated", T.ruleCount() > 800);
    t.ok("every glyph is a real one, and one character wide", (() => {
      for (const table of [T.CONDS, T.FILES, T.DIRS, T.EXTS]) {
        for (const k of Object.keys(table)) {
          const g = table[k];
          if (typeof g !== "string" || g === "") return false;
          // one codepoint, and above the BMP's ASCII — a rule that lost its
          // glyph to an encoding round-trip comes back as "" or as a literal
          // backslash-u, and both would draw as nothing
          if ([...g].length !== 1) return false;
          if (g.codePointAt(0) < 0x2000) return false;
        }
      }
      return true;
    })());
    t.ok("rule names are lowercase, or they can never match", (() => {
      for (const table of [T.FILES, T.DIRS, T.EXTS])
        for (const k of Object.keys(table))
          if (k !== k.toLowerCase()) return false;
      return true;
    })());
    // ── the two tables have to agree ──────────────────────────────────────
    // terminus.js decides what an extension IS — archive, image, video, audio,
    // font, text — and icons.js decides what it LOOKS like. An extension the
    // first knows and the second does not is a file the window will happily
    // extract or preview and draw as a blank page. That is exactly how `.bz2`,
    // `.xbm` and `.qml` were found, so the check stays.
    //
    // Loaded here rather than declared as this suite's module, because a suite
    // gets one: terminus.js is the OTHER half of the comparison.
    const path = require("path");
    const fs = require("fs");
    const vm = require("vm");
    const tsrc = fs.readFileSync(
      path.join(__dirname, "..", "..", "terminus", "terminus.js"), "utf8")
      .replace(/^\.(pragma|import)\b.*$/gm, "");
    const tctx = vm.createContext({
      Strings: { shellQuote: (s) => s, escapeHtml: (s) => s },
      Paths: { home: () => "/h", cacheDir: () => "/c", tmpDir: () => "/t",
               configDir: () => "/cf" },
      Desktop: { dirsExpr: () => "", fileName: (i) => i, launchCommand: () => "" },
      Quickshell: { env: () => "" }, Qt: {}
    });
    const decls = [...tsrc.matchAll(/^(?:const|let)\s+([A-Za-z_$][\w$]*)/gm)]
      .map((m) => m[1]);
    vm.runInContext(tsrc + "\n"
      + decls.map((n) => "try{globalThis." + n + "=" + n + "}catch(e){}").join(";"),
      tctx);

    // ── EVERY RECOGNIZED EXTENSION RESOLVES TO SOMETHING ──────────────
    // It used to demand a line in EXTS for each one, which is a stricter
    // thing than the window needs and a list nobody finishes: forty-one
    // image formats failed it, all of them obscure, and adding forty-one
    // lines pointing at the one image glyph would have left the forty-
    // second to fail the same way.
    //
    // What actually matters is that a file terminus has a KIND for never
    // draws the mark of a file it has never heard of. So the check is the
    // resolution the window performs — the table first, the kind behind
    // it — and it now covers the fallback as well as the table.
    const resolve = (ext) => {
      const g = T.glyphFor({ name: "x." + ext });
      if (!T.isPlain(g)) return g;
      const kind = tctx.isFont("x." + ext) ? "font" : tctx.kindOf("x." + ext);
      return T.kindGlyph(kind) || g;
    };
    const gap = (tableName) => {
      const tbl = tctx[tableName] || {};
      return Object.keys(tbl).filter((e) => tbl[e] && T.isPlain(resolve(e)));
    };
    for (const name of ["ARCHIVE_EXTS", "IMAGE_EXTS", "VIDEO_EXTS",
                        "AUDIO_EXTS", "FONT_EXTS", "TEXT_EXTS"]) {
      t.eq("every extension in " + name + " draws as its kind", gap(name), []);
    }
    // and the same for the kinds the listing colors rows by
    const cats = tctx.CAT_EXTS || {};
    for (const k of Object.keys(cats)) {
      const miss = Object.keys(cats[k])
        .filter((e) => cats[k][e] && T.isPlain(resolve(e)));
      t.eq("every " + k + " extension draws as its kind", miss, []);
    }
    // And the fallback table itself: a kind terminus can return with no
    // glyph behind it is the hole this was all about, one level up.
    for (const k of ["image", "video", "audio", "archive", "document",
                     "text", "font"])
      t.ok("the " + k + " kind has a fallback glyph", T.kindGlyph(k) !== "");

    // ── programs ──────────────────────────────────────────────────────────
    const nv = T.appGlyph(["neovim"]);
    t.ok("a program has a glyph", nv !== "");
    t.eq("by its command", T.appGlyph(["nvim"]), nv);
    t.eq("by its desktop file", T.appGlyph(["nvim.desktop"]), nv);
    t.eq("by its display name", T.appGlyph(["Neovim"]), nv);
    t.eq("by a command line's first word", T.appGlyph(["nvim ~/my notes/todo.md"]), nv);
    t.eq("by a path to it", T.appGlyph(["/usr/bin/nvim"]), nv);
    t.eq("a reverse-DNS id by its last part",
      T.appGlyph(["org.telegram.desktop"]), T.appGlyph(["telegram"]));
    t.eq("a spaced name hyphenated", T.appGlyph(["Google Chrome"]), T.appGlyph(["google-chrome"]));
    t.eq("nothing claims it, nothing is drawn", T.appGlyph(["kitty", "Kitty terminal"]), "");
    // a browser the font has no logo for wears md-web (user, 2026-11-04),
    // known by its desktop file's categories; one it has keeps its own
    const web = "\u{F059F}";
    t.eq("a browser known by its categories", T.appGlyph(["vivaldi-stable", "Vivaldi"], ["Network", "WebBrowser"]), web);
    t.eq("not a browser, no glyph", T.appGlyph(["kitty"], ["System", "TerminalEmulator"]), "");
    t.eq("a file transfer app by its category", T.appGlyph(["transmission-gtk", "Transmission"], ["Network", "FileTransfer", "P2P", "GTK"]), "\u{F1065}");
    t.eq("a logo beats the category", T.appGlyph(["firefox"], ["Network", "WebBrowser"]) !== web, true);
    t.eq("Brave Origin by name, no desktop file", T.appGlyph(["Brave Origin"]), web);
    t.eq("Helium by name", T.appGlyph(["net.imput.helium", "Helium"]), web);
    t.eq("a browser with a logo keeps it", T.appGlyph(["firefox"]) !== "\u{F059F}", true);
    t.eq("no names, no glyph", T.appGlyph([]), "");
    t.eq("the prototype is not a program", T.appGlyph(["constructor"]), "");
    t.eq("a program and its folder are one picture",
      T.appGlyph(["nvim"]), T.glyphFor({ name: "nvim", isDir: true }));
    t.eq("the most specific name wins", T.appGlyph(["spoot", "Spotify"]), T.appGlyph(["spotify"]));

    // ── the 11-05 additions ───────────────────────────────────────────────
    // Each reuses its relative's glyph where there is one, so a kind never
    // wears two pictures.
    const g = (name, isDir) => T.glyphFor({ name: name, isDir: !!isDir });
    t.eq("Ubisoft's directory", g("Ubisoft Game Launcher", true), "\u{F0BDA}");
    t.eq("Steam's library", g("SteamLibrary", true), "");
    t.eq("a .jsonl is JSON", g("events.jsonl"), g("a.json"));
    t.eq("a WAL is its database", g("x.sqlite-wal"), g("x.sqlite"));
    t.eq("an LevelDB table is a database", g("000003.ldb"), g("a.db"));
    t.eq("a compiled zsh file is zsh", g(".zcompdump.zwc"), g("a.zsh"));
    t.eq("a .node addon is a library", g("addon.node"), g("libx.so"));
    t.eq("an Electron .asar is an archive", g("app.asar"), g("a.zip"));
    t.eq("shaders share one glyph", g("blur.frag"), g("blur.vert"));
    t.eq("a model file", g("model.safetensors"), g("model.onnx"));
    t.eq("a Steam manifest", g("appmanifest_1.acf"), g("SteamLibrary", true));
    t.eq("nvim's shada is vim's", g("main.shada"), g("a.vim"));
    t.eq("a .desktop's .directory twin", g("x.directory"), g("x.desktop"));
    t.eq("a .backup is a .bak", g("f.backup"), g("f.bak"));
    t.eq("a file named lock", g("lock"), g("a.lock"));
    t.eq("a file named log", g("log"), g("a.log"));
    t.eq("qmldir is Qt's", g("qmldir"), g("a.qml"));
    t.eq("a shell history", g(".zsh_history"), g("a.history"));
    t.eq("an xbel is bookmarks", g("recently-used.xbel"), g("bookmarks"));
    t.eq("glab's directory is GitLab's", g("glab-cli", true), g("gitlab", true));
    t.eq("a git remote is not EA's Origin", g("origin", true), g("zzqq", true));
    t.eq("Chromium's directory", g("chromium", true), T.appGlyph(["chrome"]));
    t.eq("fontconfig wears fonts", g("fontconfig", true), g("fonts", true));
    t.eq("a suite app's directory is its app", g("ceres", true), T.appGlyph(["ceres"]));
    t.eq("dirs still ignore EXTS", g("x.jsonl", true) !== g("x.jsonl"), true);
  }
};
