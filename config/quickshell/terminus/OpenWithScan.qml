// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// WHAT OPENS A FILE, FOR A PROPERTIES CARD'S HOST — terminus' scan
// (Terminus.appsCommand) and the two changes to it, making an app the
// default and taking one away. The hosts that are not terminus (PropsHost,
// picasso's) each had a copy; picasso's had no removeApp, so the card's
// strike on an "Open with" row threw there (audit 2026-11-04). One now.
//
//     OpenWithScan { id: openWith; run: host.run; onSaid: (t) => host.said(t) }
//
// The card reads openWithApps … on the host, so the host names these for it
// (aliases) and hands findApps / setDefaultApp / removeApp on. `run` is the
// host's own: a change goes through it, and the host scans again after.

import QtQuick
import Quickshell.Io
import "terminus.js" as Terminus

Item {
  id: scan
  visible: false

  property var run: null
  signal said(string text)

  property var apps: []
  property string defaultId: ""
  property string mime: ""
  property bool scanned: false
  // the file asked about (the card writes it, through the host's alias)
  property string path: ""

  // A SCAN IN FLIGHT IS WAITED FOR, as terminus' own (FileOps.findApps):
  // asked again mid-scan, the answer that lands first was another file's
  // (or a file's on a directory, which has none) — audit 2026-11-04.
  property string again: ""
  function find(p) {
    if (p && proc.running) { scan.again = p; return; }
    scan.apps = [];
    scan.defaultId = "";
    scan.mime = "";
    scan.scanned = !p;
    if (!p) { proc.drop = proc.running; scan.again = ""; return; }
    proc.drop = false;
    proc.command = ["sh", "-c", Terminus.appsCommand(p)];
    proc.running = true;
  }
  function rescan() { if (scan.path !== "") scan.find(scan.path); }
  function setDefault(id) {
    if (!id || scan.mime === "" || !scan.run) return;
    scan.run(Terminus.setDefaultAppCommand(id, scan.mime));
    scan.said("Default set");
  }
  function remove(id) {
    if (!id || scan.mime === "" || !scan.run) return;
    scan.run(Terminus.removeAppCommand(id, scan.mime));
  }

  Process {
    id: proc
    property bool drop: false
    // the waiting ask, once this one is really gone: streamFinished comes
    // BEFORE the exit, and a find() from there still saw it running
    onExited: {
      proc.drop = false;
      const next = scan.again;
      scan.again = "";
      if (next !== "") scan.find(next);
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // a newer ask is waiting: this answer is not its — onExited runs it
        if (proc.drop || scan.again !== "") return;
        scan.apps = Terminus.parseApps(text);
        scan.mime = Terminus.parseAppsMime(text);
        scan.defaultId = Terminus.parseAppsDefault(text);
        scan.scanned = true;
      }
    }
  }
}
