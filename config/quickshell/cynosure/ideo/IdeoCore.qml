// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

import QtQuick
import Quickshell
import Quickshell.Io
import "ideo.js" as Ideo
import "../../morpheus"

// IDEO — emoji and nerd glyphs. Since 2026-11-01 what it holds is shown as
// strips of cells in Cynosure's list (an Emoji strip for any line, "em …"
// and "nf …" for them alone). This is all of Ideo that is left: the two sets,
// read in once, and the paste or the copy of one — Cynosure draws the rest.

Item {
  id: core

  // Cynosure: it closes as a glyph goes out
  property var host: null

  // Parsed once per shell session, not once per open. Neither set changes
  // underneath us, and re-reading 670KB of emoji-test.txt — then running a
  // regex over every one of its lines — stalled the UI thread.
  property var emojiCache: []
  property var nerdCache: []
  property bool nerdLoading: false

  Process {
    id: emojiProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: core.emojiCache = Ideo.parseEmojiTest(text)
    }
  }

  function fetchNerds() {
    core.nerdLoading = true;
    // curl, not XMLHttpRequest (morpheus/Net.qml says why)
    Net.request("GET", "https://www.nerdfonts.com/assets/css/webfont.css", {}, (status, body) => {
      core.nerdLoading = false;
      if (status === 200 && body) core.nerdCache = Ideo.parseNerdCss(body);
    });
  }

  // either set, read in once (the emoji file; the nerd set off the network)
  function load(mode) {
    if (mode === "nerd") {
      if (core.nerdCache.length === 0 && !core.nerdLoading) core.fetchNerds();
    } else if (core.emojiCache.length === 0 && !emojiProc.running) {
      emojiProc.command = ["cat", "/usr/share/unicode/emoji/emoji-test.txt"];
      emojiProc.running = true;
    }
  }

  function detach(script) {
    if (script) Quickshell.execDetached(["bash", "-c", script]);
  }
  function closeHost() {
    if (core.host) core.host.closeCynosure();
  }
  // into the window that had the keyboard, and onto the clipboard: after
  // the panel has gone, so the keys land where they were meant to
  function pasteGlyph(ch) {
    core.closeHost();
    core.detach("sleep 0.25 && printf '%s' " + Strings.shellQuote(ch) +
      " | wl-copy >/dev/null 2>&1 && sleep 0.15 && wtype " + Strings.shellQuote(ch));
  }
  // onto the clipboard only — and Cynosure STAYS, for the next one
  // (user, 2026-11-08); only a paste goes, its keys meant for the window
  // under it
  function copyGlyph(ch) {
    core.detach("printf '%s' " + Strings.shellQuote(ch) + " | wl-copy >/dev/null 2>&1");
  }
}
