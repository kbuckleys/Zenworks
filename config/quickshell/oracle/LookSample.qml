// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE LOOK PAGE'S DESKTOP (user, 2026-11-03: more pictures in oracle): the
// main monitor wearing the background it shows now, laid in as Fit and
// Overscan say, with the pill on its edge and a window and a menu in the
// theme's colors — so a theme, an accent or a fit picked below is seen on
// a desktop before it is lived with. Beside it, the theme's name and its
// palette, the accent first.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "../morpheus"
import "../picasso" as Pic

Item {
  id: sample

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  readonly property var mon: {
    let best = null;
    for (const r of Oracle.arrangeRects || []) {
      if (Oracle.mainMonitor !== "" && r.name === Oracle.mainMonitor) { best = r; break; }
      if (!best || r.x < best.x || (r.x === best.x && r.y < best.y)) best = r;
    }
    return best && best.w > 0 && best.h > 0 ? best : { name: "", w: 1920, h: 1080 };
  }
  readonly property real aspect: sample.mon.w / sample.mon.h

  // what the main monitor shows: a picture's path, or a plain color
  readonly property string wall: {
    const P = Pic.Picasso;
    const v = (P.shown && P.shown[sample.mon.name]) || (P.assignment && (P.assignment[sample.mon.name] || P.assignment["*"]))
      || P.firstBackground;
    return String(v || "");
  }
  // a color assignment is spelled "color:#rrggbb" (picasso.js isColor)
  readonly property bool wallIsColor: sample.wall.indexOf("color:") === 0

  readonly property var swatches: [
    ["Accent", Zenon.accent], ["Ground", Zenon.ground], ["Ink", Zenon.ink],
    ["Red", Zenon.red], ["Green", Zenon.green], ["Yellow", Zenon.yellow],
    ["Blue", Zenon.blue], ["Magenta", Zenon.magenta], ["Pink", Zenon.pink], ["Sand", Zenon.sand]
  ]

  Text {
    id: words
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: "Your background and the theme's colors, as the desktop wears them."
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

    // the screen and the palette beside it, centered as a pair
    readonly property real side: 150
    readonly property real fitH: Math.min(stage.height, (stage.width - stage.side - 24) / sample.aspect)
    readonly property real pairW: stage.fitH * sample.aspect + 24 + stage.side

    Rectangle {
      id: bezel
      x: Math.max(0, (stage.width - stage.pairW) / 2)
      anchors.verticalCenter: parent.verticalCenter
      width: Math.round(stage.fitH * sample.aspect)
      height: Math.round(stage.fitH)
      radius: Zenon.rad(4)
      color: Zenon.darken(0.35)
      border.width: 1
      border.color: Zenon.alpha(sample.highlight, 0.6)

      Rectangle {
        id: screen
        readonly property real rim: Math.max(3, Math.min(bezel.width, bezel.height) * 0.03)
        // the monitor's pixels to this one's
        readonly property real k: screen.width / sample.mon.w
        anchors.fill: parent
        anchors.margins: screen.rim
        radius: Math.max(1, Zenon.rad(4) - screen.rim / 2)
        clip: true
        color: sample.wallIsColor ? sample.wall.slice(6) : Zenon.ground

        Image {
          anchors.centerIn: parent
          visible: !sample.wallIsColor && sample.wall !== ""
          width: parent.width * Oracle.backgroundZoom
          height: parent.height * Oracle.backgroundZoom
          asynchronous: true
          cache: true
          smooth: true
          sourceSize.width: 640
          source: sample.wallIsColor || sample.wall === "" ? ""
            : Strings.fileUrl(sample.wall)
          fillMode: ({ crop: Image.PreserveAspectCrop, fit: Image.PreserveAspectFit,
                       stretch: Image.Stretch, pad: Image.Pad, tile: Image.Tile })[Oracle.backgroundFit]
                    ?? Image.PreserveAspectCrop
        }

        // the pill, on its edge, to scale
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          y: Oracle.barPosition === "top" ? Oracle.barScreenPad * screen.k
                                          : screen.height - Oracle.barScreenPad * screen.k - height
          width: Math.min(Oracle.barMaxWidth, sample.mon.w * 0.62) * screen.k
          height: Math.max(4, Oracle.barSlot * screen.k)
          radius: height / 2
          color: Zenon.panelBg
          border.width: 1
          border.color: Zenon.border
          Row {
            anchors.centerIn: parent
            spacing: 3
            Repeater {
              model: 5
              Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: index === 0 ? parent.parent.height * 1.4 : parent.parent.height * 0.3
                height: parent.parent.height * 0.3
                radius: height / 2
                color: index === 0 ? sample.highlight : Zenon.alpha(Zenon.ink, 0.35)
              }
            }
          }
        }

        // a window, in the theme's ground, its title and a lit button
        Rectangle {
          id: win
          x: screen.width * 0.08
          y: screen.height * 0.16
          width: screen.width * 0.5
          height: screen.height * 0.56
          radius: Math.max(2, Zenon.windowRadius * screen.k * 2)
          color: Zenon.layerBg
          border.width: 1
          border.color: Zenon.border
          clip: true
          Column {
            x: 8; y: 8
            spacing: 5
            Rectangle { width: win.width * 0.35; height: 5; radius: 2.5; color: Zenon.ink }
            Rectangle { width: win.width * 0.7; height: 4; radius: 2; color: Zenon.alpha(Zenon.ink, 0.35) }
            Rectangle { width: win.width * 0.6; height: 4; radius: 2; color: Zenon.alpha(Zenon.ink, 0.35) }
            Rectangle { width: win.width * 0.65; height: 4; radius: 2; color: Zenon.alpha(Zenon.ink, 0.35) }
          }
          Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            width: win.width * 0.22
            height: Math.max(6, win.height * 0.12)
            radius: Math.min(height / 2, Zenon.radiusControl)
            color: sample.highlight
          }
        }

        // a menu over it, its chosen row in the menu cursor's color
        Rectangle {
          id: menu
          x: win.x + win.width * 0.78
          y: win.y + win.height * 0.32
          width: screen.width * 0.22
          height: screen.height * 0.42
          radius: Math.max(2, Zenon.menuRadius * screen.k * 2)
          color: Zenon.menuBg
          border.width: 1
          border.color: Zenon.border
          clip: true
          Column {
            anchors.fill: parent
            anchors.topMargin: 1
            Repeater {
              model: 5
              Item {
                required property int index
                width: menu.width
                height: (menu.height - 2) / 5
                Rectangle { anchors.fill: parent; visible: index === 1; color: Zenon.menuHi }
                Rectangle {
                  x: 6
                  anchors.verticalCenter: parent.verticalCenter
                  width: menu.width * (0.4 + 0.1 * (index % 3))
                  height: 4
                  radius: 2
                  color: Zenon.alpha(Zenon.ink, index === 1 ? 0.8 : 0.4)
                }
              }
            }
          }
        }
      }
    }

    // ── the theme: its name, then its colors ──
    Column {
      x: bezel.x + bezel.width + 24
      anchors.verticalCenter: parent.verticalCenter
      width: stage.side
      spacing: 6
      Text {
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: Zenon.theme && Zenon.theme.name ? Zenon.theme.name : "Zenon"
        color: sample.fgColor
        font.family: sample.face
        font.weight: Zenon.titleWeight
        font.pixelSize: Zenon.px(15)
      }
      Text {
        textFormat: Text.PlainText
        text: Zenon.light ? "Light" : "Dark"
        color: sample.dimColor
        font.family: sample.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(12)
        bottomPadding: 4
      }
      Grid {
        columns: 5
        spacing: 6
        Repeater {
          model: sample.swatches
          Rectangle {
            required property var modelData
            required property int index
            width: 24
            height: 24
            radius: Zenon.radiusControl
            color: modelData[1]
            border.width: 1
            border.color: index === 0 ? sample.fgColor : Zenon.border
          }
        }
      }
    }
  }
}
