// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE LOCK SCREEN, CLOSE UP (user, 2026-11-03: more pictures in oracle):
// first under Idle & lock's Lock screen heading, the lock as Cerberus draws
// it, at its real size — your background blurred by Lock frost and darkened
// by Lock dimming in the theme's ground (or sharp, for Behind the lock:
// Background only), the password field Password field
// width wide with its lock glyph, and the clock's segments and the date in
// their sizes, standing as far off the screen's bottom as they do. The
// pointer shows unless Hide the cursor is on; the monitor carrying it all
// is named in the corner when there is more than one.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import QtQuick.Effects
import "../morpheus"
import "../picasso" as Pic

Item {
  id: sample

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  readonly property var mons: (Oracle.arrangeRects || []).filter((r) => r.w > 0 && r.h > 0)
  // the lock's monitor: Lock screen monitor, else the main one (Display),
  // else the leftmost
  readonly property var mon: {
    let best = null;
    const want = Oracle.lockWidgetMonitor !== "" ? Oracle.lockWidgetMonitor : Oracle.mainMonitor;
    for (const r of sample.mons) {
      if (want !== "" && r.name === want) { best = r; break; }
      if (!best || r.x < best.x || (r.x === best.x && r.y < best.y)) best = r;
    }
    return best || { name: "", w: 1920, h: 1080 };
  }

  readonly property string wall: {
    const P = Pic.Picasso;
    const v = (P.shown && P.shown[sample.mon.name]) || (P.assignment && (P.assignment[sample.mon.name] || P.assignment["*"]))
      || P.firstBackground;
    return String(v || "");
  }
  // a color assignment is spelled "color:#rrggbb" (picasso.js isColor)
  readonly property bool wallIsColor: sample.wall.indexOf("color:") === 0

  // Cerberus' own numbers (CerberusLock: the field, the glyph, the labels)
  readonly property real fieldW: Math.max(240, sample.mon.w * Oracle.lockFieldWidth)
  readonly property real fieldH: Math.max(88, sample.mon.h * 0.10)
  readonly property color clockFg: Zenon.alpha(Zenon.white, 0.85)
  readonly property color dateFg: Zenon.light ? Zenon.mix(Zenon.ink, Zenon.accentMuted, 0.3)
    : Zenon.mix(Zenon.accentSoft, Zenon.accentMuted, 0.2)

  WallClock { id: clock }

  Rectangle {
    id: glass
    anchors.fill: parent
    anchors.topMargin: 8
    anchors.bottomMargin: 8
    anchors.leftMargin: 24
    anchors.rightMargin: 24
    radius: Zenon.rad(6)
    clip: true
    color: sample.wallIsColor ? sample.wall.slice(6) : Zenon.ground

    Image {
      id: wallImg
      anchors.fill: parent
      visible: false
      asynchronous: true
      cache: true
      sourceSize.width: 960
      fillMode: Image.PreserveAspectCrop
      source: sample.wallIsColor || sample.wall === "" ? ""
        : Strings.fileUrl(sample.wall)
    }
    // Lock frost: heavier blur the higher it is set; none for Background
    // only, where the picture is the lock's ground as it is
    Image {
      anchors.fill: parent
      visible: Oracle.lockBackground === "plain" && wallImg.status === Image.Ready
      source: wallImg.source
      sourceSize.width: 960
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }
    MultiEffect {
      anchors.fill: parent
      visible: Oracle.lockBackground !== "plain" && wallImg.status === Image.Ready
      source: wallImg
      blurEnabled: true
      blurMax: 64
      blur: Math.min(1, Math.max(1, Oracle.lockFrost) / 8)
      autoPaddingEnabled: false
    }
    // Lock dimming, in the theme's ground (Cerberus' tint)
    Rectangle {
      anchors.fill: parent
      color: Zenon.alpha(Zenon.ground, Oracle.lockShade)
    }

    // the field: it paints nothing itself, only its lock glyph
    Item {
      id: field
      anchors.horizontalCenter: parent.horizontalCenter
      y: 6
      width: Math.min(sample.fieldW, glass.width - 16)
      // as tall as the lock's, or as the room over the clock lets it be
      height: Math.max(40, Math.min(sample.fieldH, glass.height - 64 - clockBox.height - 18))
      Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Zenon.radiusControl
        border.width: 1
        border.color: Zenon.alpha(sample.highlight, 0.35)
      }
      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: ""
        color: sample.clockFg
        font.family: Zenon.glyphFace
        font.pixelSize: field.height * 0.24
      }
      // the pointer, where you left it
      Text {
        visible: !Oracle.lockHideCursor
        x: field.width * 0.72
        y: field.height * 0.62
        textFormat: Text.PlainText
        text: "\u{F01BF}"
        color: Zenon.white
        font.family: Zenon.glyphFace
        font.pixelSize: Zenon.px(18)
        style: Text.Outline
        styleColor: Zenon.shade(0.6)
      }
    }

    // the clock's segments over their unlit ones, 64 px off the bottom
    Item {
      id: clockBox
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 64
      width: Math.max(ghost.implicitWidth, time.implicitWidth)
      height: time.implicitHeight
      Text {
        id: ghost
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "88:88"
        color: Zenon.alpha(Zenon.accent, 0.13)
        font.family: Zenon.clockFamily
        font.weight: Font.Bold
        font.pointSize: Oracle.lockClockSize
      }
      Text {
        id: time
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: sample.clockFg
        font.family: Zenon.clockFamily
        font.weight: Font.Bold
        font.pointSize: Oracle.lockClockSize
      }
    }
    // and the date, 25 px off it
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 25
      textFormat: Text.PlainText
      text: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
      color: sample.dateFg
      font.family: Zenon.faceMono
      font.weight: Font.Medium
      font.pointSize: Oracle.lockDateSize
    }

    // which monitor, with more than one
    Rectangle {
      visible: sample.mons.length > 1 && sample.mon.name !== ""
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 8
      width: monWord.implicitWidth + 14
      height: monWord.implicitHeight + 6
      radius: Zenon.radiusControl
      color: Zenon.alpha(Zenon.ground, 0.6)
      Text {
        id: monWord
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "On " + sample.mon.name
        color: sample.dimColor
        font.family: sample.face
        font.pixelSize: Zenon.px(11)
      }
    }
  }
}
