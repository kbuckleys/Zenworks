// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ── PLACES ───────────────────────────────────────────────────────────────
// Home and the XDG user directories, at the top of the sidebar (2026-11-02).
// Where they are comes from morpheus/UserDirs (user-dirs.dirs, then the
// environment, then ~/Name); which of them exist is asked once a window is
// shown and again whenever that file changes, so a directory you have not
// got is simply not listed. Each can be put away from the settings
// (term.placesOff, the keys turned off; empty = all on).
//
// `term` is the terminus window, as in every helper split out of it.

import QtQuick
import Quickshell.Io
import "../morpheus"

Item {
  id: places
  property var term: null

  // the sidebar's order, and the settings' — key, name, where
  readonly property var all: [
    { key: "home", label: "Home", path: Paths.home() },
    { key: "desktop", label: "Desktop", path: UserDirs.desktop },
    { key: "documents", label: "Documents", path: UserDirs.documents },
    { key: "downloads", label: "Downloads", path: UserDirs.downloads },
    { key: "music", label: "Music", path: UserDirs.music },
    { key: "pictures", label: "Pictures", path: UserDirs.pictures },
    { key: "videos", label: "Videos", path: UserDirs.videos }
  ]

  // path -> true, for the ones that are directories
  property var present: ({})

  // A directory xdg-user-dirs has turned off is written as $HOME itself;
  // that is Home's row, not a second one with another name.
  readonly property var rows: places.all.filter((p) =>
    places.present[p.path] === true
    && (p.key === "home" || p.path !== Paths.home())
    && (!places.term || places.term.placesOff.indexOf(p.key) < 0))

  function shownAt(path) {
    for (const p of places.rows) if (p.path === path) return true;
    return false;
  }

  function probe() {
    // the paths as arguments, not spliced into the script — see shArgv
    probeProc.command = ["sh", "-c",
      "for d; do [ -d \"$d\" ] && printf '%s\\036' \"$d\"; done; exit 0", "terminus-places"]
      .concat(places.all.map((p) => p.path));
    probeProc.running = true;
  }
  Process {
    id: probeProc
    stdout: StdioCollector {
      id: probeOut
      onStreamFinished: {
        const got = {};
        for (const d of String(probeOut.text).split("\x1e")) if (d !== "") got[d] = true;
        places.present = got;
      }
    }
  }

  Connections {
    target: UserDirs
    function onTextChanged() { places.probe(); }
  }
  Connections {
    target: places.term
    function onVisibleChanged() { if (places.term.visible) places.probe(); }
  }
  Component.onCompleted: places.probe()
}
