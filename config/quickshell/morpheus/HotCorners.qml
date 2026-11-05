// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// HOT CORNERS (2026-11-04) — the pointer held in a screen's corner runs
// that corner's action: Cynosure, Control Hub, Notifications, lock, screens
// off, the background shown, an app (installed, or one of the suite's), or
// a command of your own (run by sh). Every corner does nothing until
// Oracle's Hot corners page gives it something (the picture there, a
// dropdown in each corner).
//
// HOW IT IS SEEN, CHEAPLY. A corner with an action gets a 2 px layer
// surface of its own in that corner, on every screen; a corner with none
// gets nothing at all. Nothing is drawn (transparent, never repainted) and
// nothing polls: the surface hears the pointer come in and go out, and
// that is all.
//
// NOT BY ACCIDENT:
//   a pass       the pointer must stay `delay` ms (Oracle's Delay); one
//                that runs through the corner on its way elsewhere does
//                nothing. Once fired, it must leave before it fires again.
//   fullscreen   a fullscreen window on that screen's workspace (a game,
//                a film) turns its corners off
//   dragging     a drag holds the pointer to the surface it began on, so a
//                corner never hears one go by
//
// Loaded by shell.qml through a Loader, which binds `actions` and `delay`
// to Oracle (morpheus does not import oracle).

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "hypr.js" as Hypr
import "suite.js" as Suite

Item {
  id: hot

  // corner -> action: { tl, tr, bl, br }, each "none", "cynosure", "hub",
  // "notifications", "lock", "screensOff", "background", "app" or "command"
  property var actions: ({})
  // corner -> the app an "app" corner opens: a desktop entry's id, or
  // "zen:<id>" for the suite's (see suite.js)
  property var apps: ({})
  // corner -> the command a "command" corner runs
  property var commands: ({})
  property int delay: 300

  readonly property var corners: ["tl", "tr", "bl", "br"]
    .filter((c) => (hot.actions[c] || "none") !== "none")

  function run(action, corner) {
    switch (action) {
      case "cynosure": Quickshell.execDetached(["qs", "ipc", "call", "Cynosure", "toggle"]); break;
      case "hub": Quickshell.execDetached(["qs", "ipc", "call", "Hermes", "toggle"]); break;
      case "notifications": Quickshell.execDetached(["qs", "ipc", "call", "Howler", "toggle"]); break;
      case "lock": Quickshell.execDetached(["qs", "ipc", "call", "Cerberus", "lock"]); break;
      case "screensOff": Hyprland.dispatch(Hypr.dpms(false)); break;
      case "background": hot.showBackground(); break;
      case "app": {
        const id = String(hot.apps[corner] || "");
        if (Suite.isSuite(id)) {
          const cmd = Suite.command(id);
          if (cmd.length > 0) Quickshell.execDetached(cmd);
        } else if (id !== "") {
          const e = DesktopEntries.byId(id);
          if (e) e.execute();
        }
        break;
      }
      case "command": {
        const cmd = String(hot.commands[corner] || "").trim();
        if (cmd !== "") Quickshell.execDetached(["sh", "-c", cmd]);
        break;
      }
    }
  }

  // THE BACKGROUND, SHOWN: an empty workspace on that screen, and the corner
  // again goes back to where you were — while you are still on the empty
  // one it brought you to (anywhere else, it is a new trip out)
  property string leftFrom: ""
  property string wentTo: ""
  function showBackground() {
    const ws = Hyprland.focusedWorkspace;
    const here = ws ? String(ws.name) : "";
    if (hot.leftFrom !== "" && here === hot.wentTo && ws && ws.toplevels.values.length === 0) {
      Hyprland.dispatch(Hypr.focusWorkspace(hot.leftFrom));
      hot.leftFrom = "";
      hot.wentTo = "";
      return;
    }
    hot.leftFrom = here;
    Hyprland.dispatch(Hypr.focusWorkspace("empty"));
    // the name it lands on, once Hyprland says (the Connections below): a
    // callLater read the old one, the dispatch being async (audit 11-04)
    hot.wentTo = "";
  }
  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      if (hot.leftFrom !== "" && hot.wentTo === "" && Hyprland.focusedWorkspace)
        hot.wentTo = String(Hyprland.focusedWorkspace.name);
    }
  }

  Variants {
    model: {
      const out = [];
      for (const s of Quickshell.screens) for (const c of hot.corners) out.push({ screen: s, corner: c });
      return out;
    }
    PanelWindow {
      id: spot
      required property var modelData
      readonly property string corner: spot.modelData.corner
      readonly property var mon: Hyprland.monitorFor(spot.modelData.screen)
      screen: spot.modelData.screen
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "zenworks-corner"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      anchors.top: spot.corner[0] === "t"
      anchors.bottom: spot.corner[0] === "b"
      anchors.left: spot.corner[1] === "l"
      anchors.right: spot.corner[1] === "r"
      implicitWidth: 2
      implicitHeight: 2

      // fired once a stay, then quiet until the pointer has left
      property bool spent: false
      HoverHandler {
        id: over
        onHoveredChanged: {
          if (over.hovered) dwell.restart();
          else { dwell.stop(); spot.spent = false; }
        }
      }
      Timer {
        id: dwell
        interval: Math.max(50, hot.delay)
        onTriggered: {
          if (!over.hovered || spot.spent) return;
          const ws = spot.mon ? spot.mon.activeWorkspace : null;
          if (ws && ws.hasFullscreen) return;
          spot.spent = true;
          hot.run(hot.actions[spot.corner] || "none", spot.corner);
        }
      }
    }
  }
}
