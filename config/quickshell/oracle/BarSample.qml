// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE BAR PAGE'S PILL (user, 2026-10-31: more pictures in oracle): the
// morpheus pill as shell.qml builds it — its ground, rings, radius, row
// height, end caps, module spacing and padding, text size — AT ITS REAL
// SIZE, on the edge of a strip of screen, with its modules in the bar's
// order. Every module the Modules rows switch is on it, a hidden one faded,
// and a click on one shows or hides it (Oracle.set, so it is a step undo
// takes back). The modules are likenesses — a glyph, a word, morpheus'
// Meter at rest — not the live ones, which would open their panels here.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "../morpheus"

Item {
  id: bs

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.cyan

  // the one under the pointer, named in the caption
  property var hovered: null

  // the bar's order (shell.qml's barLayout), left to right; "" is the
  // stretch between the workspaces and the clock
  readonly property var modules: [
    { key: "showUpdates",       label: "Pending updates", glyph: "󰏗", ink: "cyan" },
    { key: "showNotifications", label: "Notification bell", glyph: "󰂜", ink: "cyan" },
    { key: "showHermes",        label: "Control Hub", glyph: "\u{F05A9}", ink: "cyan" },
    { key: "showWorkspaces",    label: "Workspaces", kind: "ws" },
    { key: "showTray",          label: "System tray", glyph: "\u{F0379}", ink: "dimInk" },
    { key: "" },
    { key: "showClock",         label: "Clock", kind: "clock" },
    { key: "showNetwork",       label: "Network meter", kind: "meter", inks: ["magenta", "blue"], value: 0.35 },
    { key: "showGpu",           label: "GPU meter", kind: "meter", inks: ["pink"], value: 0.2 },
    { key: "showCpu",           label: "CPU meter", kind: "meter", inks: ["red"], value: 0.45 },
    { key: "showMemory",        label: "Memory meter", kind: "meter", inks: ["yellow"], value: 0.6 },
    { key: "showVolume",        label: "Volume", kind: "meter", inks: ["green"], value: 0.7 },
    { key: "showNowPlaying",    label: "Now playing", word: "Now playing" },
    { key: "showStatus",        label: "Microphone & recording", glyph: "󰍬", ink: "sand" }
  ]

  Text {
    id: caption
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: bs.hovered
      ? bs.hovered.label + (Oracle[bs.hovered.key] ? " · click to hide it" : " · hidden, click to show it")
      : "The pill at its real size. Click a module to show or hide it."
    color: bs.dimColor
    font.family: bs.face
    font.pixelSize: Zenon.px(12)
  }

  // a slice of the screen, the pill on its edge
  Rectangle {
    id: screen
    readonly property bool barTop: Oracle.barPosition === "top"
    // edge to edge, as the pinned picture it is (OracleWindow `pinned`)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: caption.top
    anchors.bottomMargin: 10
    clip: true
    gradient: Gradient {
      GradientStop { position: 0; color: Zenon.alpha(bs.highlight, screen.barTop ? 0.30 : 0.10) }
      GradientStop { position: 1; color: Zenon.alpha(bs.highlight, screen.barTop ? 0.10 : 0.30) }
    }

    Rectangle {
      id: pill
      anchors.horizontalCenter: parent.horizontalCenter
      y: screen.barTop ? Zenon.padScreen : screen.height - Zenon.padScreen - height
      width: Math.min(Oracle.barMaxWidth, screen.width - 2 * Zenon.padScreen,
                      row.implicitWidth + 2 * Zenon.padBar)
      height: Zenon.slot
      radius: Zenon.pillRadius
      color: Zenon.panelBg
      border.width: 1
      border.color: Qt.rgba(Zenon.border.r, Zenon.border.g, Zenon.border.b, Math.min(1, Zenon.border.a * 2.5))
      opacity: Oracle.barAutohide ? 0.6 : 1
      clip: true
      Behavior on y { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }

      Row {
        id: row
        x: Zenon.padBar
        height: parent.height
        spacing: Zenon.gap

        Repeater {
          model: bs.modules

          Item {
            id: mod
            required property var modelData
            readonly property bool stretch: mod.modelData.key === ""
            readonly property bool on: !mod.stretch && !!Oracle[mod.modelData.key]
            readonly property string kind: mod.modelData.kind || (mod.modelData.word ? "word" : "glyph")
            // the stretch: room enough to read as the gap between the halves
            width: mod.stretch ? Zenon.slot * 2 : body.implicitWidth + 2 * Zenon.padModule
            height: row.height

            // under the pointer: the bar's own hover band
            Rectangle {
              anchors.fill: parent
              anchors.topMargin: 3
              anchors.bottomMargin: 3
              visible: !mod.stretch && hit.containsMouse
              radius: Math.min(height / 2, Zenon.rad(4))
              color: Zenon.alpha(Zenon.ink, 0.10)
            }

            Item {
              id: body
              anchors.centerIn: parent
              visible: !mod.stretch
              opacity: mod.on ? 1 : 0.28
              Behavior on opacity { NumberAnimation { duration: Zenon.fast } }
              implicitWidth: mod.kind === "ws" ? ws.implicitWidth
                : mod.kind === "meter" ? meters.implicitWidth
                : mod.kind === "clock" ? clock.implicitWidth
                : label.implicitWidth
              implicitHeight: Zenon.slot
              width: implicitWidth
              height: implicitHeight

              // a glyph or a word
              BarText {
                id: label
                anchors.centerIn: parent
                visible: mod.kind === "glyph" || mod.kind === "word"
                src: mod.modelData.word || mod.modelData.glyph || ""
                textColor: mod.kind === "word" ? Zenon.ink : Zenon[mod.modelData.ink || "ink"]
              }
              // three workspaces, the second the one you are on
              Row {
                id: ws
                anchors.centerIn: parent
                visible: mod.kind === "ws"
                spacing: Math.max(6, Zenon.textSize * 0.6)
                Repeater {
                  model: ["1", "2", "3"]
                  BarText {
                    required property string modelData
                    required property int index
                    numeric: true
                    src: modelData
                    textColor: index === 1 ? Zenon.cyan
                      : Zenon.light ? Zenon.dimInk : Zenon.mix(Zenon.dimInk, Zenon.cyan, 0.5)
                  }
                }
              }
              BarText {
                id: clock
                anchors.centerIn: parent
                visible: mod.kind === "clock"
                numeric: true
                src: Oracle.clock24h ? "13:00" : "1:00"
                textColor: Zenon.cyan
              }
              // the meters, at rest at a made-up reading
              Row {
                id: meters
                anchors.centerIn: parent
                visible: mod.kind === "meter"
                spacing: 2
                Repeater {
                  model: mod.kind === "meter" ? mod.modelData.inks : []
                  Meter {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    value: mod.modelData.value
                    accent: Zenon[modelData]
                  }
                }
              }
            }

            MouseArea {
              id: hit
              anchors.fill: parent
              enabled: !mod.stretch
              hoverEnabled: true
              onContainsMouseChanged: {
                if (containsMouse) bs.hovered = mod.modelData;
                else if (bs.hovered === mod.modelData) bs.hovered = null;
              }
              onClicked: Oracle.set(mod.modelData.key, !Oracle[mod.modelData.key])
            }
          }
        }
      }
    }
  }
}
