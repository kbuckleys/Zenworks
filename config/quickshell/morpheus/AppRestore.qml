// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// APP RESTORE (2026-11-04) — Oracle's "Reopen apps at login", off by
// default. The apps open when a session ends open again at the next login,
// on their workspace, and a floating one at its size and place. The work is
// morpheus/py/apprestore.py's (what is open, which .desktop file opens it,
// what was skipped and why); this is when it runs.
//
//   at startup   once Oracle's settings are read: the last session's
//                snapshot as launches (apprestore.py plan), each sent
//                through hypr.js execWith with its window rules, a little
//                apart so they map in the order they were used. Zenworks'
//                own windows are opened by their ipc calls and placed when
//                they map: the shell owns them, so no launch rule reaches
//                them. The plan is once per Hyprland session, so a shell
//                restart opens nothing.
//   afterwards   the snapshot kept current: a few seconds after a window
//                opens, closes, moves workspace or floats, and every 30 s for
//                a floating window dragged or resized (Hyprland says nothing
//                of those). apprestore.py itself writes nothing once the
//                session is ending (hyprshutdown closing the apps).
//
// Saving waits for the plan: a save before it would put this session's
// (empty) desktop over the snapshot it is about to read. Turned on mid-
// session it only saves; what was open last time is not opened now.
//
// Loaded by shell.qml through a Loader, which binds `on` to Oracle (morpheus
// does not import oracle).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "hypr.js" as Hypr

Item {
  id: restore

  property bool on: false
  // the plan has run (or was not wanted): saving may begin
  property bool armed: false
  property var queue: []
  // Zenworks windows asked for, waiting to map: title -> [placement]
  property var awaiting: ({})

  readonly property string script: Quickshell.shellDir + "/morpheus/py/apprestore.py"

  function save() {
    if (!restore.on || !restore.armed || saver.running) return;
    saver.running = true;
  }

  onOnChanged: if (restore.on) restore.save()

  // Oracle reads its file in its own onCompleted; a beat after ours, so `on`
  // is what the file says before anything is decided
  Timer {
    interval: 1500
    running: true
    onTriggered: {
      if (restore.on) planner.running = true;
      else restore.armed = true;
    }
  }

  Process {
    id: planner
    command: ["python3", restore.script, "plan"]
    stdout: StdioCollector {
      onStreamFinished: {
        let out = null;
        try { out = JSON.parse(this.text); } catch (e) { out = null; }
        restore.queue = (out && out.launch) || [];
        restore.openZen((out && out.zen) || []);
        if (out && out.skipped > 0)
          Quickshell.execDetached(["notify-send", "-a", "zenworks", "--",
            "Some apps were not reopened",
            out.skipped + (out.skipped === 1 ? " window" : " windows")
              + " could not be opened again. See ~/.local/state/zenworks/apprestore.log."]);
        if (restore.queue.length) launcher.start();
      }
    }
    onExited: if (!restore.queue.length) restore.armed = true
  }

  // one launch at a time, the least recently used first
  Timer {
    id: launcher
    interval: 300
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      const l = restore.queue.shift();
      if (l) Hyprland.dispatch(Hypr.execWith(l.cmd, l.rules || {}));
      if (!restore.queue.length) {
        launcher.stop();
        // the last ones a few seconds to map before the first save
        restore.armed = true;
        settle.restart();
      }
    }
  }

  function openZen(list) {
    if (!list.length) return;
    const w = {}, more = {};
    for (const z of list) {
      // ONE AT A TIME PER TITLE (audit 11-04): a second Terminus is a
      // "spawn" that, landing before the first window was there, only
      // showed it — two saved, one back. The next is sent once the one
      // before it has mapped (mapped(), below).
      if (w[z.title]) (more[z.title] = more[z.title] || []).push(z.ipc);
      else Quickshell.execDetached(["qs", "ipc", "call"].concat(z.ipc));
      (w[z.title] = w[z.title] || []).push(z);
    }
    restore.awaiting = w;
    restore.more = more;
    // a window that never maps (its app gone, a slow first compile) is not
    // waited for past this
    forget.restart();
  }

  // the Hyprland openwindow line: ADDRESS,WORKSPACE,CLASS,TITLE (a title
  // may hold commas, so only the first three split)
  function mapped(data) {
    const d = String(data);
    const a = d.indexOf(","), b = d.indexOf(",", a + 1), c = d.indexOf(",", b + 1);
    if (a < 0 || b < 0 || c < 0 || d.slice(b + 1, c) !== "org.quickshell") return;
    const title = d.slice(c + 1), list = restore.awaiting[title];
    if (!list || !list.length) return;
    const p = list.shift();
    Quickshell.execDetached(["hyprctl", "-q", "eval", Hypr.placeWindow(d.slice(0, a), p)]);
    const next = (restore.more[title] || []).shift();
    if (next) Quickshell.execDetached(["qs", "ipc", "call"].concat(next));
  }

  property var more: ({})
  Timer { id: forget; interval: 30000; onTriggered: { restore.awaiting = ({}); restore.more = ({}); } }

  Process {
    id: saver
    command: ["python3", restore.script, "save"]
  }

  Timer { id: settle; interval: 4000; onTriggered: restore.save() }
  Timer { interval: 30000; repeat: true; running: restore.on && restore.armed; onTriggered: restore.save() }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name;
      if (n === "openwindow" && forget.running) restore.mapped(event.data);
      if (!restore.on || !restore.armed) return;
      if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "changefloatingmode"
          || n === "moveworkspacev2" || n === "renameworkspace")
        settle.restart();
    }
  }
}
