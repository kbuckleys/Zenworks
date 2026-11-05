// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// Lookups — CYNOSURE'S WORDS THAT READ SOMETHING ELSE (2026-11-03): the
// browsers' bookmarks ("bm …") and history ("browsed …"), your GitHub
// ("github …", "prs …", "issues …"), music and videos on disk ("music …",
// "videos …"), the tray apps' menus ("menu …") and your contacts
// ("contacts …"). The popup hands it the
// line; it says whether the line is one of its words (`scoped`), the field's
// tag for it, and the rows. What it reads is read once per opening of the
// panel (GitHub's for two minutes), and filtered here as you type, except
// history, which is asked for each line.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "cynosure.js" as Cynosure
import "../artemis/artemis.js" as Artemis
import "../morpheus/icons.js" as Icons

Item {
  id: look
  visible: false

  property string query: ""
  // the panel is up: what was read is dropped when it closes
  property bool shown: false

  readonly property bool bmScoped: /^\s*bm\s/i.test(look.query)
  readonly property bool browsedScoped: /^\s*browsed\s/i.test(look.query)
  readonly property bool githubScoped: /^\s*(github|prs|issues)\s/i.test(look.query)
  readonly property bool musicScoped: /^\s*music\s/i.test(look.query)
  readonly property bool videosScoped: /^\s*videos\s/i.test(look.query)
  readonly property bool menuScoped: /^\s*menu\s/i.test(look.query)
  readonly property bool contactsScoped: /^\s*contacts?\s/i.test(look.query)
  readonly property bool scoped: look.bmScoped || look.browsedScoped || look.githubScoped
    || look.musicScoped || look.videosScoped || look.menuScoped || look.contactsScoped
  // what is typed after the word
  readonly property string line: look.scoped ? look.query.replace(/^\s*\S+\s+/, "").trim() : ""
  readonly property string ghWord: look.githubScoped ? look.query.trim().split(/\s+/)[0].toLowerCase() : ""
  readonly property var tag: look.bmScoped ? { glyph: "", text: "Bookmarks" }
    : look.browsedScoped ? { glyph: "", text: "Browsed" }
    : look.githubScoped ? { glyph: "", text: look.ghWord === "prs" ? "Pull requests" : look.ghWord === "issues" ? "Issues" : "GitHub" }
    : look.musicScoped ? { glyph: "", text: "Music" }
    : look.videosScoped ? { glyph: "", text: "Videos" }
    : look.menuScoped ? { glyph: "", text: "Menus" }
    : look.contactsScoped ? { glyph: "\uF2BB", text: "Contacts" }
    : null
  // a word with nothing under it yet: what the empty list says
  property string note: ""
  property var rows: []
  signal changed

  onShownChanged: if (!look.shown) { look.bookmarks = null; look.media = ({}); look.contacts = null; }
  onQueryChanged: later.restart()
  Timer { id: later; interval: 150; onTriggered: look.take() }

  function matches(words, q) {
    const t = String(words).toLowerCase();
    return String(q).toLowerCase().split(/\s+/).filter((w) => w !== "").every((w) => t.indexOf(w) >= 0);
  }
  function host(url) { return (/^[a-z]+:\/\/(?:www\.)?([^/?#]+)/i.exec(url) || ["", url])[1]; }
  function web(r, i, glyph, section, sub) {
    return { kind: "web", key: section + ":" + i + ":" + r.url, url: r.url, text: r.title || r.url,
      label: r.title || look.host(r.url), sub, glyph, section };
  }

  function take() {
    if (!look.scoped) { look.set([], ""); return; }
    if (look.bmScoped) {
      if (look.bookmarks === null) { look.set([], "Reading the bookmarks…"); if (!bmProc.running) bmProc.running = true; return; }
      const hits = look.bookmarks.filter((b) => look.matches(b.title + " " + b.url + " " + b.folder, look.line)).slice(0, 80);
      look.set(hits.map((b, i) => look.web(b, i, "", "Bookmarks",
        [look.host(b.url), b.folder, b.browser].filter((x) => x).join(" · "))),
        look.bookmarks.length === 0 ? "No bookmarks in Brave, Chromium, Chrome, Vivaldi, Edge, Firefox or Zen" : "Nothing matches");
      return;
    }
    if (look.browsedScoped) {
      if (look.line === "") { look.set([], "Type what you visited"); return; }
      histProc.asked = look.line;
      histProc.command = ["python3", "-I", Quickshell.shellDir + "/cynosure/bin/browsers.py", "history", look.line];
      if (histProc.running) histProc.again = true; else histProc.running = true;
      return;
    }
    if (look.githubScoped) {
      const fresh = look.github && Date.now() - look.github.at < 120000;
      if (!fresh) { if (!ghProc.running) ghProc.running = true; if (!look.github) { look.set([], "Asking GitHub…"); return; } }
      look.takeGithub();
      return;
    }
    if (look.musicScoped || look.videosScoped) {
      const kind = look.musicScoped ? "music" : "videos";
      const got = look.media[kind];
      if (!got) {
        look.set([], "Looking through " + (kind === "music" ? "Music" : "Videos") + "…");
        // the kind a run is for is kept until it ends (a switch from music
        // to videos mid-run filed the music as videos); the other is
        // asked for once this one is in
        if (!mediaProc.running) { mediaProc.kind = kind; mediaProc.running = true; }
        return;
      }
      const home = Quickshell.env("HOME");
      const hits = got.filter((p) => look.matches(Artemis.shownPath(p, home), look.line)).slice(0, 80);
      look.set(Cynosure.fileRows(hits, home, Icons.glyphFor).map((r) => Object.assign(r, { section: kind === "music" ? "Music" : "Videos" })),
        got.length === 0 ? "No " + kind + " found" : "Nothing matches");
      return;
    }
    if (look.menuScoped) { look.takeMenus(); return; }
    if (look.contactsScoped) {
      if (look.contacts === null) { look.set([], "Reading your contacts\u2026"); if (!contactsProc.running) contactsProc.running = true; return; }
      const hits = look.contacts.filter((c) => look.matches([c.name, c.org].concat(c.emails, c.phones).join(" "), look.line)).slice(0, 80);
      look.set(hits.map((c, i) => ({ kind: "contact", key: "contact:" + i + ":" + c.name, text: c.name, label: c.name,
        email: c.emails[0] || "", phone: c.phones[0] || "", path: c.path,
        sub: [c.emails[0], c.phones[0], c.org].filter((x) => x).join(" \u00B7 "), glyph: "\uF2BB", section: "Contacts" })),
        look.contacts.length === 0 ? "No contacts yet: \u201Cnew contact Ada Lovelace ada@example.org\u201D makes one" : "Nothing matches");
      return;
    }
  }
  // nothing found is said in a row of its own that does nothing
  function set(rows, note) {
    look.note = rows.length === 0 ? note : "";
    look.rows = rows.length > 0 || note === "" ? rows
      : [{ kind: "info", key: "info:" + note, text: note, label: note, sub: "", glyph: look.tag ? look.tag.glyph : "", section: "" }];
    look.changed();
  }

  // ── bookmarks ──
  property var bookmarks: null
  Process {
    id: bmProc
    command: ["python3", "-I", Quickshell.shellDir + "/cynosure/bin/browsers.py", "bookmarks"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { look.bookmarks = JSON.parse(text); } catch (e) { look.bookmarks = []; }
        look.take();
      }
    }
  }

  // ── contacts (cynosure/bin/contacts.py), read again on each opening ──
  property var contacts: null
  Process {
    id: contactsProc
    command: ["python3", "-I", Quickshell.shellDir + "/cynosure/bin/contacts.py", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { look.contacts = JSON.parse(text); } catch (e) { look.contacts = []; }
        look.take();
      }
    }
  }

  // ── history, asked for each line ──
  Process {
    id: histProc
    property string asked: ""
    property bool again: false
    onExited: if (histProc.again) { histProc.again = false; Qt.callLater(look.take); }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!look.browsedScoped || histProc.asked !== look.line) return;
        let got = [];
        try { got = JSON.parse(text); } catch (e) {}
        look.set(got.map((h, i) => look.web(h, i, "", "History",
          [look.host(h.url), Cynosure.stampOf(h.when), h.browser].filter((x) => x).join(" · "))), "Nothing visited matches");
      }
    }
  }

  // ── GitHub ──
  property var github: null
  Process {
    id: ghProc
    command: ["python3", "-I", Quickshell.shellDir + "/cynosure/bin/github.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let got = null;
        try { got = JSON.parse(text); } catch (e) {}
        look.github = Object.assign({ at: Date.now() }, got || { error: "GitHub did not answer" });
        if (look.githubScoped) look.takeGithub();
      }
    }
  }
  function takeGithub() {
    const g = look.github;
    if (!g) return;
    if (g.error) { look.set([], g.error); return; }
    const w = look.ghWord;
    const out = [];
    const add = (list, glyph, section, subOf) => {
      for (const x of list || []) {
        if (!look.matches(x.title + " " + x.repo + " " + (x.number || ""), look.line)) continue;
        out.push({ kind: "web", key: section + ":" + x.url, url: x.url, text: x.title, label: x.title,
          sub: subOf(x), glyph, section });
      }
    };
    const ref = (x) => x.repo + (x.number ? " #" + x.number : "");
    if (w === "github") add(g.notifications, "", "Notifications", (x) => [ref(x), x.reason].filter((s) => s).join(" · "));
    if (w !== "issues") {
      add(g.review, "", "Waiting on your review", ref);
      add(g.mine, "", "Your pull requests", ref);
    }
    if (w !== "prs") add(g.issues, "", "Issues assigned to you", ref);
    look.set(out, look.line !== "" ? "Nothing matches" : w === "prs" ? "No open pull requests of yours"
      : w === "issues" ? "No open issues assigned to you" : "Nothing new on GitHub");
  }

  // ── music and videos: the XDG directory's own files, newest first ──
  property var media: ({})
  Process {
    id: mediaProc
    property string kind: "music"
    command: ["sh", "-c", "d=$(xdg-user-dir \"$1\" 2>/dev/null); [ -z \"$d\" ] || [ \"$d\" = \"$HOME\" ] && d=\"$HOME/$2\"\n"
      + "find -L \"$d\" -type f \\( " + (mediaProc.kind === "music"
        ? "-iname '*.mp3' -o -iname '*.flac' -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.aac'"
        : "-iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v'")
      + " \\) -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -3000 | cut -f2-",
      "cynosure", mediaProc.kind === "music" ? "MUSIC" : "VIDEOS", mediaProc.kind === "music" ? "Music" : "Videos"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const m = Object.assign({}, look.media);
        m[mediaProc.kind] = String(text).split("\n").filter((p) => p !== "");
        look.media = m;
        look.take();
      }
    }
  }

  // ── the tray apps' menus, two levels deep ──
  // Each tray item's menu is opened while "menu …" is up (an opener asks
  // the app for it), and each submenu in it; the entries are kept here and
  // a row carries only its place among them, so the rows stay plain.
  property var menuEntries: []
  Instantiator {
    id: trays
    model: look.menuScoped && look.shown ? SystemTray.items.values.filter((t) => t.hasMenu) : []
    delegate: QtObject {
      id: tray
      required property var modelData
      readonly property var opener: QsMenuOpener { menu: tray.modelData.menu }
      readonly property var subs: Instantiator {
        model: tray.opener.children ? tray.opener.children.values.filter((e) => e.hasChildren) : []
        delegate: QsMenuOpener { required property var modelData; menu: modelData }
      }
    }
  }
  // menus arrive over DBus a moment after they are asked for
  Timer { interval: 400; repeat: true; running: look.menuScoped && look.shown; onTriggered: look.takeMenus() }
  function clean(t) { return String(t || "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_").trim(); }
  function takeMenus() {
    const entries = [], out = [];
    const add = (e, app, path) => {
      if (e.isSeparator || e.hasChildren || e.enabled === false) return;
      const label = look.clean(e.text);
      if (label === "" || !look.matches(app + " " + path + " " + label, look.line)) return;
      entries.push(e);
      out.push({ kind: "traymenu", key: "menu:" + app + ":" + path + ":" + label, at: entries.length - 1, text: label, label,
        sub: [app, path].filter((s) => s).join(" › "), glyph: e.checkState === 2 ? "" : "", section: app });
    };
    for (let i = 0; i < trays.count; ++i) {
      const t = trays.objectAt(i);
      if (!t) continue;
      const app = look.clean(t.modelData.tooltipTitle || t.modelData.title || t.modelData.id);
      const kids = t.opener.children ? t.opener.children.values : [];
      let s = 0;
      for (const e of kids) {
        if (!e.hasChildren) { add(e, app, ""); continue; }
        const sub = t.subs.objectAt(s++);
        for (const c of sub && sub.children ? sub.children.values : []) add(c, app, look.clean(e.text));
      }
    }
    look.menuEntries = entries;
    const sig = JSON.stringify(out);
    if (sig === look.menuSig) return;
    look.menuSig = sig;
    look.set(out, trays.count === 0 ? "No tray app has a menu" : "Nothing matches");
  }
  property string menuSig: ""
  onMenuScopedChanged: look.menuSig = ""
  // a menu row chosen: that entry, as a click on it would
  function trigger(at) {
    const e = look.menuEntries[at];
    if (e) e.triggered();
  }
}
