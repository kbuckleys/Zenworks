// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE NOTIFICATIONS PAGE'S SCREEN (user, 2026-11-03: more pictures in
// oracle): the main monitor as the Windows page's desk draws it, the pill on
// its edge, and the stack of toasts where Howler puts it — Position (Follow
// bar is the pill's edge), Toasts on screen, Gap above the pill, Gap between
// toasts, the widths and heights — all to the monitor's scale, so a toast a
// third of the screen wide is a third of this one. The newest is a critical
// one, in Critical color with its glow; the rest wear the title and body
// colors, their icons and the toast's Background. What each toast LOOKS like
// close up is the real one the page sends (OracleWindow.sampleToast); this
// is where and how many.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import QtQuick.Effects
import "../morpheus"

Item {
  id: sample

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  // Howler's own inks, by name (Howler.ink)
  function ink(name) {
    switch (String(name)) {
      case "muted":   return Zenon.muted;
      case "surface": return Zenon.surface;
      case "red":     return Zenon.red;
      case "green":   return Zenon.green;
      case "yellow":  return Zenon.yellow;
      case "blue":    return Zenon.blue;
      case "magenta": return Zenon.magenta;
      case "cyan":    return Zenon.accent;
      case "pink":    return Zenon.pink;
      case "sand":    return Zenon.sand;
    }
    return Zenon.white;
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
  readonly property real aspect: sample.mon.w / sample.mon.h

  // where the stack stands (Oracle.notifCorner, as HowlerToasts reads it)
  readonly property bool barTop: Oracle.barPosition === "top"
  readonly property string corner: Oracle.notifCorner(sample.barTop)
  readonly property bool atTop: sample.corner.indexOf("top") === 0
  readonly property string side: sample.corner.indexOf("-left") > 0 ? "left"
    : sample.corner.indexOf("-right") > 0 ? "right" : "center"

  // a toast, in the monitor's pixels: the lane HowlerToasts measures, and a
  // two-line toast's height inside Minimum and Maximum height
  readonly property real toastW: Math.min(Oracle.notifMaxWidth,
    Oracle.notifWidth + (Oracle.notifIcons ? Oracle.notifIconSize : 0) + Oracle.notifPadding * 4 + 2)
  readonly property real toastH: Math.max(Oracle.notifMinHeight, Math.min(Oracle.notifMaxHeight,
    Math.max(Oracle.notifIcons ? Oracle.notifIconSize : 0, Oracle.notifFontSize * 2.6) + Oracle.notifPadding * 2 + 2))
  readonly property int count: Math.max(1, Oracle.notifMaxVisible)

  Text {
    id: caption
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: "Where the toasts stack, and how many, to your screen's scale."
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
    anchors.bottom: caption.top
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
        // the monitor's pixels to this one's
        readonly property real k: screen.width / sample.mon.w
        anchors.fill: parent
        anchors.margins: screen.rim
        radius: Math.max(1, Zenon.rad(4) - screen.rim / 2)
        clip: true
        gradient: Gradient {
          GradientStop { position: 0; color: Zenon.alpha(sample.highlight, 0.30) }
          GradientStop { position: 1; color: Zenon.alpha(sample.highlight, 0.10) }
        }

        // ── the pill, on its edge, to scale ──
        Rectangle {
          id: pill
          anchors.horizontalCenter: parent.horizontalCenter
          y: sample.barTop ? Oracle.barScreenPad * screen.k
                           : screen.height - Oracle.barScreenPad * screen.k - height
          width: Math.min(Oracle.barMaxWidth, sample.mon.w * 0.62) * screen.k
          height: Math.max(3, Oracle.barSlot * screen.k)
          radius: height / 2
          color: Zenon.panelBg
          border.width: 1
          border.color: Zenon.border
        }

        // ── the stack ──
        // off the pill by Gap above the pill on the pill's own edge, off the
        // screen's edge by the same gap on the other
        readonly property real edge: (sample.atTop === sample.barTop
          ? Oracle.barScreenPad + Oracle.barSlot + Oracle.notifLift
          : Oracle.notifLift + Zenon.padScreen) * screen.k
        readonly property real tw: sample.toastW * screen.k
        readonly property real th: Math.max(4, sample.toastH * screen.k)
        readonly property real gap: Math.max(1, Oracle.notifSpacing * screen.k)

        Column {
          id: stack
          spacing: screen.gap
          x: sample.side === "left" ? Zenon.padScreen * screen.k
            : sample.side === "right" ? screen.width - Zenon.padScreen * screen.k - width
            : (screen.width - width) / 2
          y: sample.atTop ? screen.edge : screen.height - screen.edge - height
          width: screen.tw
          Behavior on x { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
          Behavior on y { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }

          Repeater {
            // newest nearest the edge it is pinned to, as Howler stacks them
            model: sample.count

            Item {
              id: toast
              required property int index
              readonly property int age: sample.atTop ? toast.index : sample.count - 1 - toast.index
              readonly property bool critical: toast.age === 0
              width: screen.tw
              height: screen.th

              // the critical one's light, past its border (Critical glows)
              RectangularShadow {
                anchors.fill: card
                visible: toast.critical && Oracle.notifGlow && Oracle.notifGlowReach > 0
                radius: card.radius
                blur: Math.max(2, Oracle.notifGlowReach * screen.k * 2)
                spread: 0
                color: Zenon.alpha(sample.ink(Oracle.notifAccent), 0.7)
              }
              Rectangle {
                id: card
                anchors.fill: parent
                radius: Math.min(height / 2, Zenon.windowRadius * screen.k * 2)
                color: Zenon.floor(Zenon.glass(Oracle.notifBgOpacity))
                border.width: 1
                border.color: toast.critical ? sample.ink(Oracle.notifAccent) : Zenon.border
                clip: true

                readonly property real pad: Math.max(2, Oracle.notifPadding * screen.k * 2)
                readonly property real lineH: Math.max(1.5, card.height * 0.12)
                // the icon, a rounded square
                Rectangle {
                  id: icon
                  visible: Oracle.notifIcons
                  x: card.pad
                  anchors.verticalCenter: parent.verticalCenter
                  width: Oracle.notifIcons ? Math.min(card.height - card.pad * 2, Oracle.notifIconSize * screen.k * 1.4) : 0
                  height: icon.width
                  radius: icon.width * 0.25
                  color: Zenon.alpha(sample.highlight, 0.55)
                }
                // the title and the body, as lines in their colors
                Column {
                  readonly property real textX: icon.visible ? icon.x + icon.width + card.pad : card.pad
                  x: textX
                  width: card.width - textX - card.pad
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: card.lineH * 0.8
                  Repeater {
                    model: [[0.55, true], [0.85, false]]
                    Item {
                      required property var modelData
                      width: parent.width
                      height: card.lineH
                      Rectangle {
                        width: parent.width * modelData[0]
                        height: parent.height
                        radius: height / 2
                        x: Oracle.notifTextAlign === "center" ? (parent.width - width) / 2
                          : Oracle.notifTextAlign === "right" ? parent.width - width : 0
                        color: modelData[1]
                          ? (toast.critical ? sample.ink(Oracle.notifAccent) : sample.ink(Oracle.notifTitleInk))
                          : Zenon.alpha(sample.ink(Oracle.notifBodyInk), 0.6)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
