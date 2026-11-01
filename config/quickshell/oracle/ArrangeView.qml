// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE DESK, DRAWN — oracle's Display arrangement, the way the old System
// Preferences had it: every lit monitor as the rectangle it covers, to scale,
// dragged to where it sits on your desk. Dropped, it snaps against the others
// (see Ora.snapArrangement) and every screen's exact position is written at
// once, under the same "keep these settings?" as any other display change.
//
// First on the Display page and edge to edge, as Time & date's map is (user,
// 2026-10-31). Each one is drawn as a monitor: a bezel, its screen in the ink
// its rows below wear, and on the main monitor a strip where the pill sits.
// While one is dragged, a ghost shows where it will land.
import QtQuick
import "oracle.js" as Ora
import "../morpheus"

Item {
  id: arr

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color headColor: Zenon.cyan
  property color highlight: Zenon.cyan

  // a click (not a drag) on a monitor: the panel takes you to its rows
  signal picked(string name)

  // What was just dropped, shown until hyprland reports the layout it made —
  // otherwise a screen would jump back to where it was for the second between
  // the write and the rescan.
  property var preview: null
  readonly property var rects: arr.preview || Oracle.arrangeRects
  Connections {
    target: Oracle
    function onArrangeRectsChanged() { arr.preview = null; }
  }

  // the main monitor (Main monitor, or the leftmost: Oracle.pickScreen's
  // rule), read off the rects so a drop moves it at once
  readonly property string mainName: {
    let best = null;
    for (const r of arr.rects) {
      if (Oracle.mainMonitor !== "" && r.name === Oracle.mainMonitor) return r.name;
      if (!best || r.x < best.x || (r.x === best.x && r.y < best.y)) best = r;
    }
    return best ? best.name : "";
  }

  // where the one being dragged would land, in the stage's pixels; null
  // while none is
  property var ghost: null

  Text {
    id: caption
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: "Drag a screen to where it sits on your desk. Click one for its settings."
    color: arr.dimColor
    font.family: arr.face
    font.pixelSize: Zenon.px(12)
  }

  Item {
    id: stage
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: caption.top
    anchors.topMargin: 28
    anchors.bottomMargin: 14
    anchors.leftMargin: 24
    anchors.rightMargin: 24

    // the whole desk, and the scale that fits it with room to drag around it
    readonly property var bounds: {
      let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
      for (const r of arr.rects) {
        x0 = Math.min(x0, r.x); y0 = Math.min(y0, r.y);
        x1 = Math.max(x1, r.x + r.w); y1 = Math.max(y1, r.y + r.h);
      }
      return isFinite(x0) ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : { x: 0, y: 0, w: 1, h: 1 };
    }
    readonly property real k: Math.min(stage.width * 0.7 / Math.max(1, bounds.w),
                                       stage.height / Math.max(1, bounds.h))
    readonly property real ox: (stage.width - bounds.w * k) / 2 - bounds.x * k
    readonly property real oy: (stage.height - bounds.h * k) / 2 - bounds.y * k

    // the gap drawn between two screens that touch, so each reads as its
    // own monitor rather than one slab
    readonly property real gap: 3

    // the drop, before it is made: snapped as Ora will snap it, then shifted
    // back onto the desk as drawn (the snap moves the top-left to 0,0)
    function landing(i, bx, by) {
      const lx = Math.round((bx - stage.ox) / stage.k);
      const ly = Math.round((by - stage.oy) / stage.k);
      const snapped = Ora.snapArrangement(arr.rects, i, lx, ly);
      const j = i === 0 ? 1 : 0;
      const dx = arr.rects[j].x - snapped[j].x, dy = arr.rects[j].y - snapped[j].y;
      return { snapped: snapped,
               x: stage.ox + (snapped[i].x + dx) * stage.k,
               y: stage.oy + (snapped[i].y + dy) * stage.k };
    }

    // where it will land
    Rectangle {
      visible: arr.ghost !== null
      x: arr.ghost ? arr.ghost.x + stage.gap / 2 : 0
      y: arr.ghost ? arr.ghost.y + stage.gap / 2 : 0
      width: arr.ghost ? arr.ghost.w - stage.gap : 0
      height: arr.ghost ? arr.ghost.h - stage.gap : 0
      radius: Zenon.rad(4)
      color: Zenon.alpha(arr.highlight, 0.10)
      border.width: 1
      border.color: Zenon.alpha(arr.highlight, 0.7)
      Behavior on x { NumberAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
      Behavior on y { NumberAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
    }

    Repeater {
      model: arr.rects

      Item {
        id: box
        required property var modelData
        required property int index

        readonly property real homeX: stage.ox + box.modelData.x * stage.k
        readonly property real homeY: stage.oy + box.modelData.y * stage.k
        readonly property var mon: Oracle.displayByName(box.modelData.name)
        readonly property bool main: box.modelData.name === arr.mainName
        readonly property bool held: boxMa.drag.active
        // the monitor's own ink, the same one its rows below wear
        readonly property color ink: Zenon[Oracle.displayAccent(box.modelData.name)]

        x: box.homeX
        y: box.homeY
        width: box.modelData.w * stage.k
        height: box.modelData.h * stage.k
        z: box.held ? 2 : 1
        // back onto its place (a drop, a rescan, the window resized),
        // never while under the pointer
        Behavior on x { enabled: !box.held; NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !box.held; NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }

        onXChanged: if (box.held) box.track()
        onYChanged: if (box.held) box.track()
        function track() {
          const l = stage.landing(box.index, box.x, box.y);
          arr.ghost = { x: l.x, y: l.y, w: box.width, h: box.height };
        }

        // the bezel: the monitor's body, a shade off the window's ground
        Rectangle {
          id: bezel
          anchors.fill: parent
          anchors.margins: stage.gap / 2
          radius: Zenon.rad(4)
          color: Zenon.darken(0.35)
          border.width: box.held || boxMa.containsMouse ? 2 : 1
          border.color: box.held ? arr.highlight
            : Zenon.alpha(box.ink, boxMa.containsMouse ? 0.95 : 0.6)
          Behavior on border.color { ColorAnimation { duration: Zenon.fast } }
        }

        // the screen inside it, lit in the monitor's ink
        Rectangle {
          id: screen
          readonly property real rim: Math.max(3, Math.min(bezel.width, bezel.height) * 0.045)
          anchors.fill: bezel
          anchors.margins: screen.rim
          radius: Math.max(1, Zenon.rad(4) - screen.rim / 2)
          clip: true
          gradient: Gradient {
            GradientStop { position: 0; color: Zenon.alpha(box.ink, box.held ? 0.42 : 0.30) }
            GradientStop { position: 1; color: Zenon.alpha(box.ink, box.held ? 0.20 : 0.10) }
          }

          // the main monitor's strip, where the pill sits
          Rectangle {
            visible: box.main
            anchors.top: parent.top
            anchors.topMargin: Math.max(2, parent.height * 0.03)
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.42
            height: Math.max(3, parent.height * 0.035)
            radius: height / 2
            color: Zenon.alpha(arr.fgColor, 0.55)
          }

          Column {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 1
            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: box.modelData.name
              color: arr.fgColor
              font.family: arr.face
              font.weight: Font.DemiBold
              font.pixelSize: Zenon.px(14)
            }
            // the model, then the mode, as room allows
            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: text !== "" && screen.height > 70
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: box.mon ? box.mon.model : ""
              color: arr.dimColor
              font.family: arr.face
              font.pixelSize: Zenon.px(11)
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: screen.height > 48
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: {
                const m = box.mon;
                if (!m) return box.modelData.w + "×" + box.modelData.h;
                let t = m.width + "×" + m.height;
                if (m.refresh > 0) t += " · " + Math.round(m.refresh) + " Hz";
                if (Number(m.scale) && Number(m.scale) !== 1) t += " · " + Number(m.scale) + "×";
                return t;
              }
              color: arr.dimColor
              font.family: arr.face
              font.pixelSize: Zenon.px(11)
            }
          }
        }

        MouseArea {
          id: boxMa
          anchors.fill: parent
          hoverEnabled: true
          drag.target: box
          drag.threshold: 4
          // it may go anywhere on the desk, never off it
          drag.minimumX: -box.width / 2
          drag.maximumX: stage.width - box.width / 2
          drag.minimumY: -box.height / 2
          drag.maximumY: stage.height - box.height / 2
          onReleased: {
            const moved = drag.active || Math.abs(box.x - box.homeX) >= 1 || Math.abs(box.y - box.homeY) >= 1;
            arr.ghost = null;
            if (!moved) { arr.picked(box.modelData.name); return; }
            const l = stage.landing(box.index, box.x, box.y);
            arr.preview = l.snapped;
            // the drag broke the bindings; they are put back, onto the new place
            box.x = Qt.binding(() => box.homeX);
            box.y = Qt.binding(() => box.homeY);
            Oracle.setDisplayPositions(l.snapped);
          }
          onCanceled: {
            arr.ghost = null;
            box.x = Qt.binding(() => box.homeX);
            box.y = Qt.binding(() => box.homeY);
          }
        }
      }
    }
  }
}
