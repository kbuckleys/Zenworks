// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE TILING PAGE'S SCREEN (user, 2026-11-03: more pictures in oracle): the
// main monitor with four windows laid out by the page's rows — the Layout,
// Dwindle's split ratio, Master's size and side (Center hangs the stack on
// both sides), Scrolling's column width and the way new columns go. The
// last window is a group of two, wearing its tabs as Tabs sets them: shown
// or not, their height, titles, stacked, gradients. Gaps and borders are
// the Windows page's, at their real size, as its desk draws them. A click
// on a window focuses it; in Scrolling the strip moves to it.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "../morpheus"

Item {
  id: sample

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  property int focused: 0
  readonly property int count: 4

  // hyprland's own rows, with their defaults while it has not been read
  function hl(key, def) {
    const v = Oracle.hyprValues["hl:" + key];
    if (v === undefined || v === null || v === "") return def;
    if (typeof def === "number") { const n = Number(v); return isNaN(n) ? def : n; }
    if (typeof def === "boolean") return v === true || v === 1 || v === "1" || v === "true";
    return String(v);
  }

  readonly property real aspect: {
    let best = null;
    for (const r of Oracle.arrangeRects || []) {
      if (Oracle.mainMonitor !== "" && r.name === Oracle.mainMonitor) { best = r; break; }
      if (!best || r.x < best.x || (r.x === best.x && r.y < best.y)) best = r;
    }
    return best && best.w > 0 && best.h > 0 ? best.w / best.h : 16 / 9;
  }

  // the four windows' shares of the work area, [x, y, w, h] as fractions
  readonly property var tiles: {
    const lay = Oracle.hyprLayout;
    const n = sample.count;
    if (lay === "master") {
      const m = Math.max(0.1, Math.min(0.9, sample.hl("master:mfact", 0.55)));
      const side = sample.hl("master:orientation", "left");
      const k = n - 1;
      if (side === "center" && k >= sample.hl("master:slave_count_for_center_master", 2)) {
        // the master in the middle, the stack shared out to both sides
        const sw = (1 - m) / 2;
        const right = Math.ceil(k / 2), left = k - right;
        const out = [[sw, 0, m, 1]];
        for (let i = 0; i < right; ++i) out.push([sw + m, i / right, sw, 1 / right]);
        for (let i = 0; i < left; ++i) out.push([0, i / left, sw, 1 / left]);
        return out;
      }
      if (side === "top" || side === "bottom") {
        const my = side === "top" ? 0 : 1 - m;
        const sy = side === "top" ? m : 0;
        const out = [[0, my, 1, m]];
        for (let i = 0; i < k; ++i) out.push([i / k, sy, 1 / k, 1 - m]);
        return out;
      }
      const mx = side === "right" ? 1 - m : 0;
      const sx = side === "right" ? 0 : m;
      const out = [[mx, 0, m, 1]];
      for (let i = 0; i < k; ++i) out.push([sx, i / k, 1 - m, 1 / k]);
      return out;
    }
    if (lay === "scrolling") {
      // a strip of columns, scrolled so the focused one stands in the middle
      const c = Math.max(0.1, Math.min(1, sample.hl("scrolling:column_width", 0.95)));
      const dir = sample.hl("scrolling:direction", "right");
      const sign = dir === "left" || dir === "up" ? -1 : 1;
      const out = [];
      if (dir === "down" || dir === "up") {
        const y0 = (1 - c) / 2 - sign * sample.focused * c;
        for (let i = 0; i < n; ++i) out.push([0, y0 + sign * i * c, 1, c]);
      } else {
        const x0 = (1 - c) / 2 - sign * sample.focused * c;
        for (let i = 0; i < n; ++i) out.push([x0 + sign * i * c, 0, c, 1]);
      }
      return out;
    }
    // dwindle: each window splits the space the last one left, the longer
    // side across, at the split ratio
    const r = Math.max(0.05, Math.min(0.95, sample.hl("dwindle:default_split_ratio", 1) / 2));
    const out = [];
    let x = 0, y = 0, w = 1, h = 1;
    for (let i = 0; i < n; ++i) {
      if (i === n - 1) { out.push([x, y, w, h]); break; }
      if (w * sample.aspect >= h) {
        out.push([x, y, w * r, h]);
        x += w * r; w *= 1 - r;
      } else {
        out.push([x, y, w, h * r]);
        y += h * r; h *= 1 - r;
      }
    }
    return out;
  }

  // the group's tabs (Tabs)
  readonly property bool tabsOn: sample.hl("group:groupbar:enabled", true)
  readonly property int tabsH: sample.hl("group:groupbar:height", 24)
  readonly property bool tabTitles: sample.hl("group:groupbar:render_titles", true)
  readonly property bool tabsStacked: sample.hl("group:groupbar:stacked", false)
  readonly property bool tabGradients: sample.hl("group:groupbar:gradients", true)

  Text {
    id: words
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: (({ master: "Master", scrolling: "Scrolling" })[Oracle.hyprLayout] || "Dwindle")
      + ", four windows; the last is a group of two. Click a window to focus it."
    color: sample.dimColor
    font.family: sample.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(12)
  }

  Item {
    id: stage
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: words.top
    anchors.topMargin: 16
    anchors.bottomMargin: 10
    anchors.leftMargin: 24
    anchors.rightMargin: 24

    Rectangle {
      id: bezel
      readonly property real fitH: Math.min(stage.height, stage.width / sample.aspect)
      anchors.centerIn: parent
      width: Math.round(bezel.fitH * sample.aspect)
      height: Math.round(bezel.fitH)
      radius: Zenon.rad(4)
      color: Zenon.darken(0.35)
      border.width: 1
      border.color: Zenon.alpha(sample.highlight, 0.6)

      Rectangle {
        id: screen
        readonly property real rim: Math.max(3, Math.min(bezel.width, bezel.height) * 0.03)
        anchors.fill: parent
        anchors.margins: screen.rim
        radius: Math.max(1, Zenon.rad(4) - screen.rim / 2)
        clip: true
        gradient: Gradient {
          GradientStop { position: 0; color: Zenon.alpha(sample.highlight, 0.30) }
          GradientStop { position: 1; color: Zenon.alpha(sample.highlight, 0.10) }
        }

        readonly property real go: Oracle.hyprGapsOut
        readonly property real gi: Oracle.hyprGapsIn
        readonly property rect area: Qt.rect(screen.go, screen.go,
          Math.max(0, screen.width - 2 * screen.go), Math.max(0, screen.height - 2 * screen.go))

        Repeater {
          model: sample.count

          Item {
            id: win
            required property int index
            readonly property var f: sample.tiles[win.index] || [0, 0, 0, 0]
            readonly property bool active: sample.focused === win.index
            readonly property bool group: win.index === sample.count - 1
            readonly property real l: win.f[0] > 0.001 ? screen.gi : 0
            readonly property real r: win.f[0] + win.f[2] < 0.999 ? screen.gi : 0
            readonly property real t: win.f[1] > 0.001 ? screen.gi : 0
            readonly property real b: win.f[1] + win.f[3] < 0.999 ? screen.gi : 0
            x: screen.area.x + win.f[0] * screen.area.width + win.l
            y: screen.area.y + win.f[1] * screen.area.height + win.t
            width: Math.max(0, win.f[2] * screen.area.width - win.l - win.r)
            height: Math.max(0, win.f[3] * screen.area.height - win.t - win.b)
            Behavior on x { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }

            // a group's tabs ride above its window, inside its tile
            readonly property bool tabs: win.group && sample.tabsOn
            readonly property real barH: !win.tabs ? 0
              : sample.tabsStacked ? sample.tabsH * 2 + 2 : sample.tabsH
            Column {
              id: bar
              visible: win.tabs
              width: parent.width
              spacing: 2
              Repeater {
                // side by side: one row of two; stacked: a row each
                model: sample.tabsStacked ? 2 : 1
                Row {
                  id: tabRow
                  required property int index
                  width: bar.width
                  spacing: 2
                  Repeater {
                    model: sample.tabsStacked ? 1 : 2
                    Rectangle {
                      required property int index
                      readonly property bool lit: (sample.tabsStacked ? tabRow.index : index) === 0
                      width: sample.tabsStacked ? tabRow.width : (tabRow.width - 2) / 2
                      height: sample.tabsH
                      radius: Zenon.rad(3)
                      color: !sample.tabGradients ? "transparent"
                        : lit ? Zenon.alpha(sample.highlight, 0.45) : Zenon.alpha(Zenon.border, 0.35)
                      border.width: sample.tabGradients ? 0 : 1
                      border.color: lit ? sample.highlight : Zenon.border
                      Text {
                        visible: sample.tabTitles && sample.tabsH >= 12
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: parent.lit ? "Terminus" : "Plato"
                        color: sample.fgColor
                        font.family: sample.face
                        font.weight: Zenon.weight
                        font.pixelSize: Math.max(8, Math.min(Zenon.px(12), sample.tabsH * 0.55))
                      }
                    }
                  }
                }
              }
            }

            readonly property int bw: Oracle.hyprBorder
            Item {
              id: frame
              anchors.fill: parent
              anchors.topMargin: win.barH > 0 ? win.barH + 2 : 0
              Rectangle {
                anchors.fill: parent
                visible: win.bw > 0
                radius: Zenon.corner + win.bw
                color: "transparent"
                border.width: win.bw
                border.color: win.active ? sample.highlight : Zenon.alpha(Zenon.border, 0.3)
                Behavior on border.color { ColorAnimation { duration: Zenon.fast } }
              }
              Rectangle {
                id: body
                anchors.fill: parent
                anchors.margins: win.bw
                radius: Zenon.corner
                color: Zenon.layerBg
                clip: true
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: String(win.index + 1)
                  color: win.active ? sample.highlight : Zenon.alpha(Zenon.ink, 0.4)
                  font.family: sample.face
                  font.weight: Zenon.titleWeight
                  font.pixelSize: Math.max(10, Math.min(Zenon.px(22), body.height * 0.35))
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              onPressed: sample.focused = win.index
            }
          }
        }
      }
    }
  }
}
