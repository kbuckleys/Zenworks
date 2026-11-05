// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE HOT CORNERS PAGE'S SCREEN (2026-11-04): the main monitor as the
// Notifications page draws it, a dropdown at each of its corners, and each
// corner that does something lit with its action's glyph. The dropdowns
// are this window's own (OracleWindow hands in openEnum), so the card that
// opens is the one every other row opens; the rows under the picture are
// the same settings, for search and the keyboard.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import Quickshell
import "../morpheus"
import "oracle.js" as Ora
import "../morpheus/suite.js" as Suite

Item {
  id: sample

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent
  // OracleWindow's dropdown: openEnum(key, pointInWindow), closeEnum(), and
  // the key open now
  property var openEnum: null
  property var closeEnum: null
  property string openKey: ""
  // the face the card hangs from and which side it is on (CardPopup.joined)
  property Item openChip: null
  property string openJoined: ""
  property real openMenuW: 0

  readonly property var keys: ({ tl: "hotCornerTL", tr: "hotCornerTR", bl: "hotCornerBL", br: "hotCornerBR" })
  readonly property var glyphs: ({ cynosure: "\uF002", hub: "\uF1DE", notifications: "\uF0F3",
                                   background: "\uF03E", lock: "\uF023", screensOff: "\uF186",
                                   command: "\uF120" })
  function actionOf(c) { return String(Oracle[sample.keys[c]] || "none"); }
  // an "Open an app" corner's app, its name and glyph
  function appOf(c) { return String(Oracle[sample.keys[c] + "App"] || ""); }
  function appName(c) {
    return Suite.nameOf(sample.appOf(c), (id) => {
      const e = DesktopEntries.byId(id);
      return e ? String(e.name) : id;
    });
  }
  function glyphOf(c) {
    const a = sample.actionOf(c);
    if (a !== "app") return sample.glyphs[a] || "";
    const id = sample.appOf(c);
    return Strings.appGlyph([Suite.isSuite(id) ? id.slice(4) : id, sample.appName(c)]) || Suite.WINDOW;
  }

  // the main monitor (Oracle.pickScreen's rule, as the desk has it), 1920
  // by 1080 when none is known
  readonly property var mon: {
    let best = null;
    for (const r of Oracle.arrangeRects || []) {
      if (Oracle.mainMonitor !== "" && r.name === Oracle.mainMonitor) { best = r; break; }
      if (!best || r.x < best.x || (r.x === best.x && r.y < best.y)) best = r;
    }
    return best && best.w > 0 && best.h > 0 ? best : { w: 1920, h: 1080 };
  }
  readonly property bool barTop: Oracle.barPosition === "top"

  // the dropdowns stand above and below the screen, at its corners; the
  // picture is short (pinned), so the screen is drawn the picture's whole
  // width rather than to the monitor's shape (user, 2026-11-04)
  readonly property int chipH: 26
  readonly property int gap: 8

  Item {
    id: stage
    anchors.fill: parent
    anchors.topMargin: 14
    anchors.bottomMargin: 14
    anchors.leftMargin: 24
    anchors.rightMargin: 24

    Rectangle {
      id: bezel
      // room above and below for the dropdowns
      anchors.centerIn: parent
      width: stage.width
      height: stage.height - (sample.chipH + sample.gap) * 2
      radius: Zenon.rad(4)
      color: Zenon.darken(0.35)
      border.width: 1
      border.color: Zenon.alpha(sample.highlight, 0.6)

      Rectangle {
        id: screen
        readonly property real rim: Math.max(3, Math.min(bezel.width, bezel.height) * 0.03)
        // drawn wider than the monitor's shape: across by the width, up and
        // down by the height
        readonly property real k: screen.width / sample.mon.w
        readonly property real kH: screen.height / sample.mon.h
        anchors.fill: parent
        anchors.margins: screen.rim
        radius: Math.max(1, Zenon.rad(4) - screen.rim / 2)
        clip: true
        gradient: Gradient {
          GradientStop { position: 0; color: Zenon.alpha(sample.highlight, 0.30) }
          GradientStop { position: 1; color: Zenon.alpha(sample.highlight, 0.10) }
        }

        // the pill, on its edge, to scale
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          y: sample.barTop ? Oracle.barScreenPad * screen.kH
                           : screen.height - Oracle.barScreenPad * screen.kH - height
          width: Math.min(Oracle.barMaxWidth, sample.mon.w * 0.62) * screen.k
          height: Math.max(3, Oracle.barSlot * screen.kH)
          radius: height / 2
          color: Zenon.panelBg
          border.width: 1
          border.color: Zenon.border
        }

        // each corner that does something: a lit quarter and its glyph
        Repeater {
          model: ["tl", "tr", "bl", "br"]
          Item {
            id: hot
            required property string modelData
            readonly property string action: sample.actionOf(hot.modelData)
            readonly property bool lit: hot.action !== "none"
            readonly property bool atLeft: hot.modelData[1] === "l"
            readonly property bool atTop: hot.modelData[0] === "t"
            readonly property real r: Math.min(screen.width, screen.height) * 0.22
            width: hot.r
            height: hot.r
            x: hot.atLeft ? 0 : screen.width - hot.r
            y: hot.atTop ? 0 : screen.height - hot.r
            opacity: hot.lit ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
            // a disc centered on the corner: the screen's clip leaves a quarter
            Rectangle {
              width: hot.r * 2
              height: hot.r * 2
              radius: hot.r
              x: hot.atLeft ? -hot.r : 0
              y: hot.atTop ? -hot.r : 0
              color: Zenon.alpha(sample.highlight, 0.28)
              border.width: 1
              border.color: Zenon.alpha(sample.highlight, 0.7)
            }
            Text {
              x: hot.atLeft ? hot.r * 0.18 : hot.r - width - hot.r * 0.18
              y: hot.atTop ? hot.r * 0.14 : hot.r - height - hot.r * 0.14
              text: sample.glyphOf(hot.modelData)
              textFormat: Text.PlainText
              color: sample.highlight
              font.family: sample.face
              font.pixelSize: Zenon.px(16)
            }
          }
        }
      }
    }

    // a dropdown at each corner, outside the screen, flush with its side
    Repeater {
      model: ["tl", "tr", "bl", "br"]
      DropFace {
        id: chip
        required property string modelData
        readonly property string key: sample.keys[chip.modelData]
        readonly property var spec: Oracle.spec(chip.key)
        readonly property bool keyOpen: sample.openKey === chip.key
        // as wide as its choice, and as its menu while that is out (DropFace);
        // the right-hand ones widen leftwards, away from the screen's edge
        growLeft: chip.modelData[1] === "r"
        height: sample.chipH
        x: chip.modelData[1] === "l" ? bezel.x : bezel.x + bezel.width - width
        y: chip.modelData[0] === "t" ? bezel.y - height - sample.gap : bezel.y + bezel.height + sample.gap
        joined: sample.openChip === chip ? sample.openJoined : ""
        menuWidth: sample.openChip === chip ? sample.openMenuW : 0
        contentWidth: chipLabel.implicitWidth
        pressed: chipMa.pressed
        pressColor: Qt.rgba(sample.highlight.r, sample.highlight.g, sample.highlight.b, 0.18)
        chevronInk: sample.dimColor

        Text {
          id: chipLabel
          anchors.left: parent.left
          anchors.leftMargin: chip.inset
          anchors.right: chip.chevron.left
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: sample.actionOf(chip.modelData) === "app" && sample.appOf(chip.modelData) !== ""
                ? sample.appName(chip.modelData)
                : chip.spec ? Ora.display(chip.spec, Oracle[chip.key]) : ""
          color: sample.fgColor
          font.family: sample.face
          font.weight: Font.Medium
          font.pixelSize: Zenon.px(15)
        }
        MouseArea {
          id: chipMa
          anchors.fill: parent
          onClicked: {
            if (chip.keyOpen) { if (sample.closeEnum) sample.closeEnum(); return; }
            if (sample.openEnum) sample.openEnum(chip.key, chip.mapToItem(null, 0, chip.height + 4), chip);
          }
          onWheel: (w) => { Oracle.nudge(chip.key, w.angleDelta.y > 0 ? 1 : -1); w.accepted = true; }
        }
      }
    }
  }
}
