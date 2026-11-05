// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE WINDOWS PAGE'S DESK (user, 2026-10-31: more pictures in oracle): the
// main monitor as Display's ArrangeView draws it, with the pill on its edge
// and three tiled windows in the Tiling layout. What the page's rows set is
// drawn AT ITS REAL SIZE — the outer gaps, the inner gaps (twice between
// two windows, as hyprland counts them), the border and the corner — so
// 8 px looks like 8 px; only the screen itself is small. The windows not in
// focus wear Dim unfocused windows and Unfocused opacity, the one in focus
// Focused opacity; a click on another moves the focus there (pointing is
// enough under Window focus: Follow pointer). Read off Oracle, so a row
// moved is drawn as it moves.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "../morpheus"

Item {
  id: desk

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  // which of the three has the focus here (nothing in the session moves)
  property int focused: 0
  readonly property bool followPointer: Number(Oracle.inputValues["input:follow_mouse"]) === 1

  // hyprland's own rows, with their defaults while it has not been read
  function hl(key, def) {
    const v = Number(Oracle.hyprValues["hl:" + key]);
    return isNaN(v) ? def : v;
  }

  // the main monitor's shape (Oracle.pickScreen's rule: Main monitor, or
  // the leftmost), 16:9 when none is known
  readonly property real aspect: {
    let best = null;
    for (const r of Oracle.arrangeRects || []) {
      if (Oracle.mainMonitor !== "" && r.name === Oracle.mainMonitor) { best = r; break; }
      if (!best || r.x < best.x || (r.x === best.x && r.y < best.y)) best = r;
    }
    return best && best.w > 0 && best.h > 0 ? best.w / best.h : 16 / 9;
  }

  Text {
    id: caption
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: "Gaps, borders and corners at their real size. "
      + (desk.followPointer ? "Point at a window to focus it." : "Click a window to focus it.")
    color: desk.dimColor
    font.family: desk.face
    font.pixelSize: Zenon.px(12)
  }

  Item {
    id: stage
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: caption.top
    anchors.topMargin: 16
    anchors.bottomMargin: 10
    anchors.leftMargin: 24
    anchors.rightMargin: 24

    // the monitor, as large as fits at its own shape
    Rectangle {
      id: bezel
      readonly property real fitH: Math.min(stage.height, stage.width / desk.aspect)
      anchors.centerIn: parent
      width: Math.round(bezel.fitH * desk.aspect)
      height: Math.round(bezel.fitH)
      radius: Zenon.rad(4)
      color: Zenon.darken(0.35)
      border.width: 1
      border.color: Zenon.alpha(desk.highlight, 0.6)

      Rectangle {
        id: screen
        readonly property real rim: Math.max(3, Math.min(bezel.width, bezel.height) * 0.03)
        anchors.fill: parent
        anchors.margins: screen.rim
        radius: Math.max(1, Zenon.rad(4) - screen.rim / 2)
        clip: true
        gradient: Gradient {
          GradientStop { position: 0; color: Zenon.alpha(desk.highlight, 0.30) }
          GradientStop { position: 1; color: Zenon.alpha(desk.highlight, 0.10) }
        }

        // ── the pill, on its edge ──
        // as the bar wears it: its row height, off the edge by Gap to
        // screen edge; under Autohide it overlays and keeps no room
        readonly property bool barTop: Oracle.barPosition === "top"
        readonly property real reserve: !Oracle.barReserveSpace || Oracle.barAutohide ? 0
          : Oracle.barScreenPad + Oracle.barSlot + Oracle.barWindowGap
        Rectangle {
          id: pill
          anchors.horizontalCenter: parent.horizontalCenter
          y: screen.barTop ? Oracle.barScreenPad : screen.height - Oracle.barScreenPad - height
          width: Math.min(Oracle.barMaxWidth, screen.width * 0.62)
          height: Oracle.barSlot
          radius: height / 2
          z: 2
          color: Zenon.panelBg
          border.width: 1
          border.color: Zenon.border
          opacity: Oracle.barAutohide ? 0.45 : 1
          Behavior on y { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
          // a few modules, as dots and a word
          Row {
            anchors.centerIn: parent
            spacing: Math.max(4, Oracle.barGap)
            Repeater {
              model: 5
              Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: index === 2 ? pill.height * 1.4 : pill.height * 0.3
                height: pill.height * 0.3
                radius: height / 2
                color: index === 2 ? Zenon.alpha(Zenon.ink, 0.55) : Zenon.alpha(Zenon.ink, 0.3)
              }
            }
          }
        }

        // ── the windows ──
        // the work area: the screen less the pill's room, less Outer gaps
        readonly property real go: Oracle.hyprGapsOut
        readonly property real gi: Oracle.hyprGapsIn
        readonly property rect area: Qt.rect(screen.go,
          (screen.barTop ? screen.reserve : 0) + screen.go,
          Math.max(0, screen.width - 2 * screen.go),
          Math.max(0, screen.height - screen.reserve - 2 * screen.go))

        // each window's share of the area, [x, y, w, h] as fractions: the
        // Tiling layout's first three windows (SettingArt's "layout" kind,
        // with the split and the master's size read off its rows)
        readonly property var tiles: {
          const lay = Oracle.hyprLayout;
          if (lay === "master") {
            const m = Math.max(0.1, Math.min(0.9, desk.hl("master:mfact", 0.55)));
            return [[0, 0, m, 1], [m, 0, 1 - m, 0.5], [m, 0.5, 1 - m, 0.5]];
          }
          // the strip scrolled so the focused column stands in the middle
          if (lay === "scrolling") {
            const c = Math.max(0.2, Math.min(1, desk.hl("scrolling:column_width", 0.95)));
            const col = [0, 1, -1];
            const x = (1 - c) / 2 - col[desk.focused] * c;
            return col.map((n) => [x + n * c, 0, c, 1]);
          }
          const s = Math.max(0.05, Math.min(0.95, desk.hl("dwindle:default_split_ratio", 1) / 2));
          return [[0, 0, s, 1], [s, 0, 1 - s, 0.5], [s, 0.5, 1 - s, 0.5]];
        }

        Repeater {
          model: 3

          Item {
            id: win
            required property int index
            readonly property var f: screen.tiles[win.index]
            readonly property bool active: desk.focused === win.index
            // Inner gaps on every side that meets another window, none on
            // the area's own edge (Outer gaps is there already)
            readonly property real l: win.f[0] > 0.001 ? screen.gi : 0
            readonly property real r: win.f[0] + win.f[2] < 0.999 ? screen.gi : 0
            readonly property real t: win.f[1] > 0.001 ? screen.gi : 0
            readonly property real b: win.f[1] + win.f[3] < 0.999 ? screen.gi : 0
            x: screen.area.x + win.f[0] * screen.area.width + win.l
            y: screen.area.y + win.f[1] * screen.area.height + win.t
            width: Math.max(0, win.f[2] * screen.area.width - win.l - win.r)
            height: Math.max(0, win.f[3] * screen.area.height - win.t - win.b)
            opacity: win.active ? desk.hl("decoration:active_opacity", 1) : Oracle.hyprInactiveOpacity
            Behavior on x { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Zenon.fast } }

            // the border, in the theme's colors as ThemeSync hands them to
            // hyprland (the hairline at 65% focused, 30% not); the corner
            // is the window's, grown by the border as hyprland draws it
            readonly property int bw: Oracle.hyprBorder
            Rectangle {
              anchors.fill: parent
              visible: win.bw > 0
              radius: Zenon.corner + win.bw
              color: "transparent"
              border.width: win.bw
              border.color: Zenon.alpha(Zenon.border, win.active ? 0.65 : 0.3)
              Behavior on border.color { ColorAnimation { duration: Zenon.fast } }
            }
            Rectangle {
              id: body
              anchors.fill: parent
              anchors.margins: win.bw
              radius: Zenon.corner
              color: Zenon.layerBg
              clip: true
              Column {
                x: 10; y: 10
                spacing: 6
                Repeater {
                  model: [0.75, 0.55, 0.65, 0.4]
                  Rectangle {
                    required property real modelData
                    width: Math.max(0, body.width * modelData - 20)
                    height: 5
                    radius: 2.5
                    color: Zenon.alpha(Zenon.ink, 0.22)
                  }
                }
              }
              // Dim unfocused windows: hyprland lays black over them
              Rectangle {
                anchors.fill: parent
                radius: body.radius
                color: Zenon.shade(1)
                opacity: win.active ? 0 : Oracle.hyprDimInactive
                Behavior on opacity { NumberAnimation { duration: Zenon.fast } }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: desk.followPointer
              onPressed: desk.focused = win.index
              onContainsMouseChanged: if (containsMouse && desk.followPointer) desk.focused = win.index
            }
          }
        }
      }
    }
  }
}
