// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE WORKSPACES PAGE'S SCREENS (user, 2026-11-03: more pictures in
// oracle): your monitors as Display arranges them, each holding the
// workspaces Screens gives it, and the ones left to Any on a shelf under
// them. Every workspace wears its layout as a small picture — its own from
// Layouts, or Tiling's (dimmer) when it has none. A monitor's name is
// under it; the main one is lit.
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

  readonly property int count: 10

  function wsValue(n, field) {
    const v = Oracle.hyprValues["hl:zen:ws:" + n + ":" + field];
    return v === undefined || v === null ? "" : String(v);
  }

  // the monitors, or one 16:9 stand-in while none is known
  readonly property var mons: {
    const rs = (Oracle.arrangeRects || []).filter((r) => r.w > 0 && r.h > 0);
    return rs.length > 0 ? rs : [{ name: "", standIn: true, x: 0, y: 0, w: 1920, h: 1080 }];
  }
  readonly property string mainName: {
    if (Oracle.mainMonitor !== "") return Oracle.mainMonitor;
    let best = null;
    for (const r of sample.mons)
      if (!best || r.x < best.x || (r.x === best.x && r.y < best.y)) best = r;
    return best ? best.name : "";
  }
  // workspace numbers by monitor name ("" = Any), a name no longer plugged in
  // counted as Any
  readonly property var byMon: {
    // (the stand-in screen holds none: with no monitors known, all are Any)
    const names = sample.mons.filter((m) => !m.standIn).map((m) => m.name);
    const out = ({});
    for (let n = 1; n <= sample.count; ++n) {
      let m = sample.wsValue(n, "monitor");
      if (names.indexOf(m) < 0) m = "";
      (out[m] = out[m] || []).push(n);
    }
    return out;
  }
  readonly property var anywhere: sample.byMon[""] || []

  // the desk's bounds, to scale every monitor into the stage
  readonly property rect bounds: {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const r of sample.mons) {
      x0 = Math.min(x0, r.x); y0 = Math.min(y0, r.y);
      x1 = Math.max(x1, r.x + r.w); y1 = Math.max(y1, r.y + r.h);
    }
    return Qt.rect(x0, y0, x1 - x0, y1 - y0);
  }

  // a layout as three tiles, as the Layouts rows' own art draws them
  function tilesOf(lay) {
    if (lay === "master") return [[0, 0, 0.55, 1], [0.55, 0, 0.45, 0.5], [0.55, 0.5, 0.45, 0.5]];
    if (lay === "scrolling") return [[-0.3, 0, 0.6, 1], [0.32, 0, 0.6, 1], [0.94, 0, 0.6, 1]];
    return [[0, 0, 0.5, 1], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]];
  }

  component Chip: Rectangle {
    id: chip
    required property int num
    readonly property string own: sample.wsValue(chip.num, "layout")
    readonly property string lay: chip.own !== "" ? chip.own : Oracle.hyprLayout
    width: 46
    height: 24
    radius: Zenon.radiusControl
    color: Zenon.alpha(Zenon.ink, 0.07)
    border.width: 1
    border.color: chip.own !== "" ? Zenon.alpha(sample.highlight, 0.7) : Zenon.border
    Text {
      x: 6
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: String(chip.num)
      color: sample.fgColor
      font.family: sample.face
      font.weight: Zenon.titleWeight
      font.pixelSize: Zenon.px(12)
    }
    // the layout, as three tiles
    Item {
      id: pic
      anchors.right: parent.right
      anchors.rightMargin: 5
      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 12
      clip: true
      Repeater {
        model: sample.tilesOf(chip.lay)
        Rectangle {
          required property var modelData
          x: modelData[0] * pic.width + 0.5
          y: modelData[1] * pic.height + 0.5
          width: Math.max(1, modelData[2] * pic.width - 1)
          height: Math.max(1, modelData[3] * pic.height - 1)
          radius: 1
          color: chip.own !== "" ? sample.highlight : Zenon.alpha(Zenon.ink, 0.45)
        }
      }
    }
  }

  Text {
    id: words
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: "Which screen each workspace opens on, and its layout. Lit: a layout of its own."
    color: sample.dimColor
    font.family: sample.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(12)
  }

  // the workspaces left to Any
  Row {
    id: shelf
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: words.top
    anchors.bottomMargin: 10
    spacing: 6
    visible: sample.anywhere.length > 0
    height: visible ? 24 : 0
    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "Any screen"
      color: sample.dimColor
      font.family: sample.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(12)
      rightPadding: 4
    }
    Repeater {
      model: sample.anywhere
      Chip { required property int modelData; num: modelData }
    }
  }

  Item {
    id: stage
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: shelf.top
    anchors.topMargin: 16
    anchors.bottomMargin: 26
    anchors.leftMargin: 24
    anchors.rightMargin: 24

    readonly property real k: Math.min(stage.width / Math.max(1, sample.bounds.width),
                                       stage.height / Math.max(1, sample.bounds.height))
    readonly property real ox: (stage.width - sample.bounds.width * stage.k) / 2
    readonly property real oy: (stage.height - sample.bounds.height * stage.k) / 2

    Repeater {
      model: sample.mons

      Rectangle {
        id: mon
        required property var modelData
        readonly property bool main: mon.modelData.name === sample.mainName
        readonly property var nums: mon.modelData.standIn ? [] : sample.byMon[mon.modelData.name] || []
        x: stage.ox + (mon.modelData.x - sample.bounds.x) * stage.k + 3
        y: stage.oy + (mon.modelData.y - sample.bounds.y) * stage.k + 3
        width: mon.modelData.w * stage.k - 6
        height: mon.modelData.h * stage.k - 6
        radius: Zenon.rad(4)
        color: Zenon.darken(0.35)
        border.width: 1
        border.color: Zenon.alpha(sample.highlight, mon.main ? 0.8 : 0.35)
        gradient: Gradient {
          GradientStop { position: 0; color: Zenon.alpha(sample.highlight, mon.main ? 0.30 : 0.16) }
          GradientStop { position: 1; color: Zenon.alpha(sample.highlight, mon.main ? 0.10 : 0.05) }
        }

        Flow {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 5
          Repeater {
            model: mon.nums
            Chip { required property int modelData; num: modelData }
          }
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.bottom
          anchors.topMargin: 4
          textFormat: Text.PlainText
          text: mon.modelData.name !== "" ? mon.modelData.name : "Your screen"
          color: mon.main ? sample.fgColor : sample.dimColor
          font.family: sample.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(11)
        }
      }
    }
  }
}
