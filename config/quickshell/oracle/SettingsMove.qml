// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// SETTINGSMOVE — Configuration's Export settings and Import settings (2026-10-21),
// the files half: Oracle only asks (exportAsked / importAsked), since it
// cannot reach terminus' picker or morpheus' writer.
//
// Export reads the files a bundle may hold (Ora.makeBundle) and saves one
// .json where you choose. Import reads one, says what is in it on a sheet,
// and only on Import writes it: what is here now first, to
// settings-before-import.json beside oracle.json, so any import can be
// taken back by importing that. The screen arrangement comes along only if
// ticked — another machine's screens are rarely this one's.

import QtQuick
import Quickshell
import Quickshell.Io
import "oracle.js" as Ora
import "../morpheus"
import "../morpheus/controls" as Controls
import "../terminus"

Item {
  id: move
  anchors.fill: parent
  property var fileManager: null

  readonly property string stateDir: Oracle.statePath.replace(/\/[^/]*$/, "")
  function absOf(rel) {
    if (rel === "oracle.json") return Oracle.statePath;
    if (rel.startsWith("hypr/")) return Oracle.hyprLuaDir + "/" + rel.slice(5);
    // a custom theme is the user's (Oracle.themesDir), never the shipped
    // directory: export found none there, and import wrote into it (audit 10-31)
    if (rel.startsWith("themes/")) return Oracle.themesDir + "/" + rel.slice(7);
    // an app's own (Ora.appFiles): beside oracle.json, in the data
    // directory, or beside the clipboard's ledger
    const app = Ora.appFiles()[rel];
    if (app) {
      const name = rel.slice(5);
      return app.at === "data" ? Paths.dataDir() + "/" + name
        : app.at === "clip" ? Paths.cacheDir() + "/cliphist/" + name
        : move.stateDir + "/" + name;
    }
    return "";
  }
  // what was done, said as a toast: the window has no line of its own
  function tell(t) { Quickshell.execDetached(["notify-send", "-a", "oracle", "Settings", t]); }

  Component { id: readerComp; FileView { blockLoading: true; printErrors: false } }
  function readText(path) {
    const f = readerComp.createObject(move, { path: path });
    const t = f && f.loaded ? f.text() : null;
    if (f) f.destroy();
    return t;
  }
  // what is here now, as a bundle's files
  function current() {
    const rels = ["oracle.json", "hypr/keys.lua", "hypr/wake.lua", "hypr/effects.lua", "hypr/defaults.lua", "hypr/input.lua", "hypr/inputmethod.lua", "hypr/windows.lua", "hypr/startup.lua", "hypr/monitors.lua", "hypr/hyprland.lua"]
      .concat(Oracle.themeOptions.filter((o) => o.custom).map((o) => "themes/" + o.value + ".json"));
    const files = {};
    for (const rel of rels) {
      // oracle.json from memory: Oracle.save() just before is a write that
      // may not have landed, and the file read back was the one before it
      const t = rel === "oracle.json" ? Oracle.stateText() : move.readText(move.absOf(rel));
      if (t !== null && t !== "") files[rel] = t;
    }
    // each app's settings, and only those (Ora.appSettingsOf)
    for (const rel in Ora.appFiles()) {
      const t = Ora.appSettingsOf(rel, move.readText(move.absOf(rel)) || "");
      if (t !== "") files[rel] = t;
    }
    return files;
  }

  AtomicWriter { id: writer; tag: "oracle-settings" }

  // ── EXPORT ──
  function exportNow() {
    if (!move.fileManager) { move.tell("Terminus is needed to choose where"); return; }
    Oracle.save();
    const day = Qt.formatDate(new Date(), "yyyy-MM-dd");
    move.fileManager.choose(false, Paths.home(), (paths) => {
      if (!paths || !paths.length) return;
      const out = /\.json$/i.test(paths[0]) ? paths[0] : paths[0] + ".json";
      writer.write(out, Ora.makeBundle(move.current(), new Date().toISOString()), (ok) =>
        move.tell(ok ? "Settings exported to " + out.replace(/.*\//, "") : "Settings could not be written to " + out));
    }, "zenworks-settings-" + day + ".json");
  }

  // ── IMPORT ──
  property var pending: null
  property bool withScreens: false
  property int pick: 0
  function importAsk() {
    if (!move.fileManager) { move.tell("Terminus is needed to choose the file"); return; }
    move.fileManager.choose(false, Paths.home(), (paths) => {
      if (!paths || !paths.length) return;
      const b = Ora.readBundle(move.readText(paths[0]) || "");
      if (!b.ok) { move.tell(b.why); return; }
      // a shipped theme of the same name is never replaced (see Ora.bundleThemeWritable)
      for (const rel of Object.keys(b.files)) {
        if (rel.startsWith("themes/") && !Ora.bundleThemeWritable(move.readText(move.absOf(rel)))) {
          delete b.files[rel];
          b.skipped++;
        }
      }
      if (!Object.keys(b.files).length) { move.tell("There are no settings in it to bring here"); return; }
      // the hypr files written fresh from their values: hyprland runs them,
      // and a bundle's own text could hold any Lua (Ora.sanitizeBundleFile)
      for (const rel of Object.keys(b.files)) {
        b.files[rel] = Ora.sanitizeBundleFile(rel, b.files[rel], Oracle.bindList);
        // an app's file with no settings in it is nothing to bring
        if (b.files[rel] === "" && rel.startsWith("apps/")) { delete b.files[rel]; b.skipped++; }
      }
      // and what it would run, shown on the sheet before it is taken
      b.commands = Ora.bundleCommands(b.files);
      move.withScreens = false;
      move.pick = 0;
      move.pending = b;
    });
  }
  function importNow() {
    const b = move.pending;
    move.pending = null;
    if (!b) return;
    Oracle.save();
    // what is here now, first
    writer.write(move.stateDir + "/settings-before-import.json", Ora.makeBundle(move.current(), new Date().toISOString()));
    const jobs = [];
    move.appsCame = false;
    for (const rel in b.files) {
      if (rel === "hypr/monitors.lua" && !move.withScreens) continue;
      const to = move.absOf(rel);
      if (to === "") continue;
      // an app's settings laid over its file here, which keeps the rest
      if (rel.startsWith("apps/")) {
        const into = Ora.appSettingsInto(rel, b.files[rel], move.readText(to));
        if (into === "") continue;
        jobs.push([to, into]);
        move.appsCame = true;
      } else jobs.push([to, b.files[rel]]);
    }
    const n = jobs.length;
    // once the LAST write has landed (the writer goes one at a time, so a
    // fixed wait could read half of them): the settings read back, hyprland told
    let left = n;
    for (const j of jobs) writer.write(j[0], j[1], () => { if (--left === 0) after.restart(); });
    if (n === 0) after.restart();
    move.tell(n + (n === 1 ? " file imported" : " files imported") + " · the old ones kept in settings-before-import.json"
      + (move.appsCame ? " · the shell restarts to read the apps' own" : ""));
  }
  // the apps read their files once, at start: an import with theirs in it
  // ends with a restart (Oracle's own, scripts/restart.sh)
  property bool appsCame: false
  Timer {
    id: after
    interval: 50
    onTriggered: {
      Oracle.reloadFromDisk();
      Oracle.scanThemes();
      Quickshell.execDetached(["hyprctl", "reload"]);
      if (move.appsCame) restartLater.restart();
    }
  }

  // a beat for oracle.json to be read back and hyprland told first
  Timer { id: restartLater; interval: 1500; onTriggered: Oracle.run("actionRestart") }

  Connections {
    target: Oracle
    function onExportAsked() { move.exportNow(); }
    function onImportAsked() { move.importAsk(); }
  }

  onPendingChanged: if (move.pending) Qt.callLater(() => sheetKeys.forceActiveFocus())
  // the sheet's keys: no field to hold them, so held here
  Item {
    id: sheetKeys
    Keys.onPressed: (e) => {
      e.accepted = true;
      if (e.key === Qt.Key_Escape) move.pending = null;
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) body.chose(move.pick);
      else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab) move.pick = 1 - move.pick;
      else e.accepted = false;
    }
  }
  InputShield { visible: !!move.pending; onClicked: move.pending = null }
  Sheet {
    id: sheet
    shown: !!move.pending
    cardW: 480
    cardH: body.implicitHeight
    ConfirmBody {
      id: body
      width: parent.width
      question: "Import these settings?"
      glyph: "󰋺"
      glyphInk: Zenon.accent
      detail: move.pending ? (move.pending.made !== "" ? "Exported " + Qt.formatDateTime(new Date(move.pending.made), "d MMM yyyy, hh:mm") + ". " : "")
        + "What is here now is kept first." : ""
      items: move.pending ? Ora.bundleWords(move.pending.files).filter((w) => w !== "Screen arrangement") : []
      choices: [{ label: "Import", ink: Zenon.accent }, { label: "Cancel", ink: Zenon.accentMuted }]
      pick: move.pick
      onPicked: (i) => move.pick = i
      onChose: (i) => { if (i === 0) move.importNow(); else move.pending = null; }
      // ── WHAT IT WOULD RUN ──
      // startup apps run at login and default apps from the keys: a bundle
      // from someone else is only as safe as these, so they are read first
      Column {
        id: cmdBox
        readonly property var cmds: move.pending && move.pending.commands ? move.pending.commands : []
        width: parent.width
        spacing: 6
        visible: cmdBox.cmds.length > 0
        Text {
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          text: cmdBox.cmds.length === 1 ? "It runs this command" : "It runs these commands"
          color: Zenon.accentMuted
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(13)
        }
        Rectangle {
          width: parent.width
          height: cmdCol.implicitHeight + 12
          radius: Zenon.windowRadius
          color: Zenon.wash(0.04)
          border.width: 1
          border.color: Zenon.border
          Column {
            id: cmdCol
            x: 12
            y: 6
            width: parent.width - 24
            Repeater {
              model: cmdBox.cmds.slice(0, 8)
              delegate: Column {
                required property var modelData
                width: cmdCol.width
                topPadding: 3
                bottomPadding: 3
                opacity: modelData.off ? Zenon.disabledDim : 1
                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: modelData.what + (modelData.off ? " · off" : "")
                  color: Zenon.accentMuted
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(12)
                }
                Text {
                  width: parent.width
                  elide: Text.ElideMiddle
                  textFormat: Text.PlainText
                  text: modelData.command
                  color: Zenon.white
                  font.family: Zenon.faceMono
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(13)
                }
              }
            }
            Text {
              visible: cmdBox.cmds.length > 8
              width: cmdCol.width
              height: 22
              verticalAlignment: Text.AlignVCenter
              text: "And " + (cmdBox.cmds.length - 8) + " more"
              color: Zenon.accentMuted
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(13)
            }
          }
        }
      }
      Item {
        width: parent.width
        height: visible ? 36 : 0
        visible: !!move.pending && ("hypr/monitors.lua" in move.pending.files)
        Controls.Check {
          x: 16
          anchors.verticalCenter: parent.verticalCenter
          label: "Screen arrangement too (from that machine)"
          lit: move.withScreens
          onToggled: move.withScreens = !move.withScreens
        }
      }
    }
  }
}
