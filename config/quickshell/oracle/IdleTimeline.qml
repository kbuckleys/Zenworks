// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE IDLE & LOCK PAGE'S TIMELINE (user, 2026-10-31: more pictures in
// oracle): what happens as you stay away, on one line from the moment you
// stop. Socordia's three timers (SocordiaDaemon `listeners`) as markers —
// Device lighting off after, Lock after, and Display's Screens off after —
// each on a lane of its own so their names never cross, and the line
// darkening step by step past each one. Drag a marker to move its timer
// (30 s steps, as the rows have); drag it into Never at the end and that
// timer is off. The time the line spans is chosen from the timers when
// none is held, so a drag does not change the scale under the hand.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "../morpheus"

Item {
  id: tl

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  // the timers, in seconds (0 is never); a held marker's own reading
  // stands in for its setting until it is let go
  property string held: ""
  property int heldSecs: 0
  function secs(key) { return tl.held === key ? tl.heldSecs : Number(Oracle[key]) || 0; }

  // lanes top to bottom, in the order they usually come
  readonly property var marks: [
    { key: "idleKeyboardSecs", label: "Lighting off", glyph: "\u{F030C}", ink: "sand", max: 3600 },
    { key: "idleLockSecs", label: "Lock", glyph: "\u{F033E}", ink: "cyan", max: 3600 },
    { key: "idleScreenOffSecs", label: "Screens off", glyph: "\u{F0379}", ink: "blue", max: 7200 }
  ]

  // the span: the shortest round one that holds every timer with room
  // to spare, held still while a marker is
  property int span: 1800
  function fitSpan() {
    const most = Math.max(Oracle.idleKeyboardSecs, Oracle.idleLockSecs, Oracle.idleScreenOffSecs);
    for (const s of [300, 600, 900, 1800, 3600, 7200])
      if (most * 1.15 <= s) return s;
    return 7200;
  }
  readonly property int fitted: tl.fitSpan()
  onFittedChanged: if (tl.held === "") tl.span = tl.fitted
  Component.onCompleted: tl.span = tl.fitted

  // a tick every this many seconds, six or so along the span
  readonly property int tick: tl.span <= 600 ? 60 : tl.span <= 1800 ? 300 : tl.span <= 3600 ? 600 : 1800

  function words(s) {
    if (s <= 0) return "never";
    if (s < 60) return s + " s";
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
    if (h > 0) return h + " h" + (m > 0 ? " " + m + " min" : "");
    return m + " min" + (r > 0 ? " " + r + " s" : "");
  }

  Text {
    id: caption
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: !Oracle.idleEnabled ? "Idle timers are off, so none of these happen."
      : "From the moment you stop. Drag a marker to move it; into Never to turn it off."
    color: tl.dimColor
    font.family: tl.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(12)
  }

  Item {
    id: stage
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: caption.top
    anchors.leftMargin: 24
    anchors.rightMargin: 24
    anchors.topMargin: 14
    anchors.bottomMargin: 8
    opacity: Oracle.idleEnabled ? 1 : 0.45

    readonly property real laneH: Zenon.px(22)
    readonly property real neverW: 76
    // the line: 0 at its left, the span at the start of Never
    readonly property real x0: 0
    readonly property real x1: stage.width - stage.neverW - 8
    function at(s) { return s <= 0 ? stage.x1 + 8 + 12 : stage.x0 + Math.min(1, s / tl.span) * (stage.x1 - stage.x0); }
    readonly property real trackY: tl.marks.length * stage.laneH + 8
    readonly property real trackH: 10

    // ── the line, darker past each timer ──
    // the steps in order of when they come: awake, then each one's dark
    readonly property var stops: {
      const on = tl.marks.map((m) => tl.secs(m.key)).filter((s) => s > 0).sort((a, b) => a - b);
      return on;
    }
    Rectangle {
      x: stage.x0
      y: stage.trackY
      width: stage.x1 - stage.x0
      height: stage.trackH
      radius: height / 2
      color: Zenon.alpha(tl.highlight, 0.55)
      clip: true
      Repeater {
        model: stage.stops
        Rectangle {
          required property int modelData
          required property int index
          x: stage.at(modelData) - stage.x0
          width: parent.width - x
          height: parent.height
          color: Zenon.shade(0.28)
        }
      }
    }
    // Never: where an off timer waits
    Rectangle {
      x: stage.x1 + 8
      y: stage.trackY - 3
      width: stage.neverW
      height: stage.trackH + 6
      radius: height / 2
      color: "transparent"
      border.width: 1
      border.color: Zenon.border
      // to the right: an off timer's dot waits at the left end
      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        textFormat: Text.PlainText
        text: "Never"
        color: tl.dimColor
        font.family: tl.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(11)
      }
    }
    // the ticks and their times, under the line
    Repeater {
      model: Math.floor(tl.span / tl.tick) + 1
      Item {
        required property int index
        x: stage.at(index * tl.tick || 0.0001)
        y: stage.trackY + stage.trackH + 3
        Rectangle { x: -0.5; width: 1; height: 4; color: Zenon.border }
        Text {
          x: -implicitWidth / 2
          y: 6
          textFormat: Text.PlainText
          text: index === 0 ? "0" : tl.words(index * tl.tick)
          color: tl.dimColor
          font.family: tl.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(11)
        }
      }
    }

    // ── the markers, a lane each ──
    Repeater {
      model: tl.marks

      Item {
        id: mark
        required property var modelData
        required property int index
        readonly property int s: tl.secs(mark.modelData.key)
        readonly property color ink: Zenon[mark.modelData.ink]
        readonly property bool holding: tl.held === mark.modelData.key
        property real cx: stage.at(mark.s)
        Behavior on cx { enabled: !mark.holding; NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }

        // the line down from its name to the track
        Rectangle {
          x: mark.cx - 1
          y: mark.index * stage.laneH + stage.laneH / 2
          width: 2
          height: stage.trackY + stage.trackH - y
          color: mark.ink
          opacity: mark.s > 0 ? 0.9 : 0.4
        }
        Rectangle {
          x: mark.cx - width / 2
          y: stage.trackY + stage.trackH / 2 - height / 2
          width: 12; height: 12; radius: 6
          color: mark.ink
          border.width: 2
          border.color: Zenon.ground
        }
        // its name and its time, kept on the stage
        Rectangle {
          id: chip
          readonly property real want: mark.cx - width / 2
          x: Math.max(stage.x0 - 16, Math.min(stage.width - width, chip.want))
          y: mark.index * stage.laneH + 1
          width: chipRow.implicitWidth + 16
          height: stage.laneH - 2
          radius: Zenon.radiusControl
          color: mark.holding ? Zenon.mix(Zenon.surface, mark.ink, 0.25) : Zenon.surface
          border.width: 1
          border.color: Zenon.alpha(mark.ink, 0.7)
          Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: mark.modelData.glyph
              color: mark.ink
              font.family: Zenon.glyphFace
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(13)
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: mark.modelData.label + " · " + tl.words(mark.s)
              color: Zenon.ink
              font.family: tl.face
              font.weight: Zenon.titleWeight
              font.pixelSize: Zenon.px(12)
            }
          }
        }

        // dragged by its name or its line: the press's x is the marker's
        MouseArea {
          id: hit
          x: Math.min(chip.x, mark.cx - 8)
          y: chip.y
          width: Math.max(chip.x + chip.width, mark.cx + 8) - x
          height: stage.trackY + stage.trackH + 6 - y
          hoverEnabled: true
          preventStealing: true
          function secsAt(px) {
            if (px > stage.x1 + 4) return 0;
            const f = Math.max(0, Math.min(1, (px - stage.x0) / (stage.x1 - stage.x0)));
            return Math.max(30, Math.min(mark.modelData.max, Math.round(f * tl.span / 30) * 30));
          }
          onPressed: (m) => {
            tl.heldSecs = mark.s;
            tl.held = mark.modelData.key;
          }
          onPositionChanged: (m) => {
            if (!pressed) return;
            tl.heldSecs = secsAt(mapToItem(stage, m.x, m.y).x);
          }
          onReleased: {
            const k = tl.held, v = tl.heldSecs;
            tl.held = "";
            if (k !== "" && v !== Number(Oracle[k])) Oracle.set(k, v);
            tl.span = tl.fitted;
          }
          onCanceled: { tl.held = ""; tl.span = tl.fitted; }
        }
      }
    }
  }
}
