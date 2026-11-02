// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A SUITE WINDOW ASKED FOR AGAIN, SOMEWHERE ELSE. An ordinary app opened a
// second time asks Hyprland to activate its window (xdg-activation); with
// misc:focus_on_activate off, Hyprland marks it urgent instead of jumping,
// and the bar's workspace flashes (Workspaces.qml). The suite's windows are
// quickshell's, and asking for one again only dispatched a focus: a window
// on another workspace pulled you there, one in the hidden special did
// nothing at all (OffSpecial put the special away again), and nothing
// flashed (user, 2026-11-01: Delphi in the special, opened from 2).
//
// So every manager's "already open" path calls raise(title) here: a window
// on screen is focused as before; one that is not is marked as asking, and
// Workspaces.qml lights its workspace exactly as Hyprland's urgent does.
// Hyprland has no dispatcher that sets urgent, so the mark is the shell's
// own, cleared the way Hyprland clears its: when the window gets focus, or
// when it goes.
//
//   Attention.raise("delphi")      focus it, or flash where it is
//   Attention.raise(title, addr)   the same, for the window at that address
//   Attention.lit(workspace)       a window on it is asking (Workspaces)

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "hypr.js" as Hypr

Singleton {
  id: root

  // addresses (no 0x) of suite windows asking
  property var asking: []

  // the special each monitor shows, by monitor name ("" for none): socket2's
  // activespecial, seeded from the monitors' last answer
  property var specials: ({})
  Component.onCompleted: {
    const o = {};
    for (const m of Hyprland.monitors.values) {
      const sw = m.lastIpcObject && m.lastIpcObject.specialWorkspace;
      o[m.name] = sw && sw.name ? String(sw.name) : "";
    }
    root.specials = o;
  }

  function norm(a) { return String(a || "").toLowerCase().replace(/^0x/, ""); }

  // where you can see it now, so focusing it moves nothing: its numbered
  // workspace shown and not under a special, or its special shown
  function onScreen(t) {
    const ws = t.workspace;
    if (!ws) return true;
    const name = String(ws.name);
    const mon = ws.monitor ? ws.monitor.name : "";
    if (name.startsWith("special:")) {
      if (Object.values(root.specials).indexOf(name) >= 0) return true;
      const fw = Hyprland.focusedWorkspace;
      return !!fw && String(fw.name) === name;
    }
    return (ws.active || ws.focused) && !root.specials[mon];
  }

  // `address` (0x or not) when the window knows its own: one of several
  // sharing a title (plato's)
  // Only entries with a live Wayland handle: quickshell's list can keep a
  // window Hyprland has dropped (2026-11-02: an "oracle" there after its
  // surface died, focused by address on every press)
  function raise(title, address) {
    const want = root.norm(address);
    const all = Hyprland.toplevels.values.filter((t) => !!t.wayland && (want !== ""
      ? root.norm(t.address) === want
      : t.title === title && t.wayland.appId === "org.quickshell"));
    // not known to Hyprland yet (mapped this instant): the old dispatch
    if (all.length === 0) {
      Hyprland.dispatch(want !== "" ? Hypr.focusWindow(Hypr.byAddress(want)) : Hypr.focusTitle(title));
      return;
    }
    const here = all.find((t) => root.onScreen(t));
    if (here) { Hyprland.dispatch(Hypr.focusWindow(Hypr.byAddress(here.address))); return; }
    const add = all.map((t) => root.norm(t.address)).filter((a) => a !== "" && root.asking.indexOf(a) < 0);
    if (add.length > 0) root.asking = root.asking.concat(add);
  }

  // a window on this workspace is asking
  function lit(ws) {
    if (!ws || root.asking.length === 0) return false;
    const vals = Hyprland.toplevels.values;
    return root.asking.some((a) => vals.some((t) => t.workspace === ws && root.norm(t.address) === a));
  }

  // Hyprland clears its mark when the window takes focus. Focus may already
  // be on it, left in a hidden special, so being shown while it holds focus
  // clears it too; a window gone takes its mark with it.
  function settle() {
    if (root.asking.length === 0) return;
    const vals = Hyprland.toplevels.values;
    const act = Hyprland.activeToplevel;
    const keep = root.asking.filter((a) => {
      const t = vals.find((x) => root.norm(x.address) === a);
      return !!t && !!t.wayland && !(act && root.norm(act.address) === a && root.onScreen(t));
    });
    if (keep.length !== root.asking.length) root.asking = keep;
  }

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() { root.settle(); }
    function onFocusedWorkspaceChanged() { root.settle(); }
    function onRawEvent(event) {
      if (event.name === "activespecial") {
        const parts = String(event.data).split(",");
        const o = Object.assign({}, root.specials);
        o[(parts[1] || "").trim()] = (parts[0] || "").trim();
        root.specials = o;
        root.settle();
      } else if (event.name === "closewindow") {
        root.settle();
      }
    }
  }
}
