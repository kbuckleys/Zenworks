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
  property color highlight: Zenon.accent

  // the one under the pointer, named in the caption
  property var hovered: null

  // the bar's order (shell.qml's barLayout), left to right, WITH ITS
  // SPACERS (user, 2026-11-02: "represent the bar WYSIWYG"): the bar's row
  // has no spacing of its own — every space is an item — so neither has
  // this one. `div` is a Divider (or DividerSlot), `gap` a Gap between
  // meters, each there under shell.qml's own rule (bs.spacerOn). The one
  // liberty: a module switched off stays, faded, so it can be clicked back.
  readonly property var modules: [
    { key: "showUpdates",       label: "Pending updates", glyph: "󰏗", ink: "cyan" },
    { key: "showNotifications", label: "Notification bell", glyph: "󰂜", ink: "cyan" },
    { key: "showHermes",        label: "Control Hub", glyph: "\u{F05A9}", ink: "cyan" },
    { div: "left" },
    { key: "showWorkspaces",    label: "Workspaces", kind: "ws" },
    { key: "showTray",          label: "System tray", glyph: "\u{F0379}", ink: "dimInk" },
    { div: "clock" },
    { key: "showClock",         label: "Clock", kind: "clock" },
    { div: "meters" },
    { key: "showNetwork",       label: "Network meter", kind: "meter", inks: ["magenta", "blue"], value: 0.35 },
    { gap: 0 },
    { key: "showGpu",           label: "GPU meter", kind: "meter", inks: ["pink"], value: 0.2 },
    { gap: 1 },
    { key: "showCpu",           label: "CPU meter", kind: "meter", inks: ["red"], value: 0.45 },
    { gap: 2 },
    { key: "showMemory",        label: "Memory meter", kind: "meter", inks: ["yellow"], value: 0.6 },
    { gap: 3 },
    { key: "showVolume",        label: "Volume", kind: "meter", inks: ["green"], value: 0.7 },
    { div: "audio" },
    { key: "showNowPlaying",    label: "Now playing", word: "Now playing" },
    { div: "status" },
    { key: "showStatus",        label: "Microphone & recording", glyph: "󰍬", ink: "sand" }
  ]
  // shell.qml's meterRun (jobs left out: the picture has none running)
  readonly property var meterRun: [Oracle.showNetwork, Oracle.showGpu, Oracle.showCpu, Oracle.showMemory,
    Oracle.showVolume || Oracle.showNowPlaying]
  // whether a spacer is there, as the bar decides it
  function spacerOn(m) {
    if (m.gap !== undefined) {
      if (!bs.meterRun[m.gap]) return false;
      for (let k = m.gap + 1; k < bs.meterRun.length; ++k) if (bs.meterRun[k]) return true;
      return false;
    }
    switch (m.div) {
    case "left": return (Oracle.showUpdates || Oracle.showNotifications || Oracle.showHermes) && Oracle.showWorkspaces;
    case "clock": return Oracle.showClock;
    case "meters": return bs.meterRun.indexOf(true) >= 0;
    case "audio": return Oracle.showVolume && Oracle.showNowPlaying;
    case "status": return Oracle.showStatus;
    }
    return false;
  }

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
    font.weight: Zenon.weight
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

    // the pill's light shadow at rest (shell.qml's LayerShadow, morph 0)
    MenuShadow {
      panel: pill
      visible: !Oracle.barBare
      cornerRadius: pill.radius
      ink: Zenon.alpha(Zenon.menuShadowInk, Zenon.menuShadowInk.a * 0.55)
      grow: 4
      softness: 16
      drop: 2
      opacity: pill.opacity
    }
    // the pill's two outer rings (shell.qml), fainter outward; not frameless
    Repeater {
      model: Oracle.barBare ? [] : [[1, 1.2], [2, 0.7]]
      Rectangle {
        required property var modelData
        x: pill.x - modelData[0]
        y: pill.y - modelData[0]
        width: pill.width + modelData[0] * 2
        height: pill.height + modelData[0] * 2
        radius: pill.radius + modelData[0]
        color: "transparent"
        border.width: 1
        border.color: Zenon.alpha(Zenon.border, Zenon.border.a * modelData[1])
        opacity: pill.opacity
      }
    }

    Rectangle {
      id: pill
      anchors.horizontalCenter: parent.horizontalCenter
      y: screen.barTop ? Zenon.padScreen : screen.height - Zenon.padScreen - height
      width: Math.min(Oracle.barMaxWidth, screen.width - 2 * Zenon.padScreen,
                      row.implicitWidth + 2 * Zenon.padBar)
      height: Zenon.slot
      radius: Zenon.pillRadius
      // Frameless: the modules alone, as shell.qml's pillFrame at rest
      color: Oracle.barBare ? "transparent" : Zenon.panelBg
      border.width: Oracle.barBare ? 0 : 1
      border.color: Zenon.alpha(Zenon.border, Math.min(1, Zenon.border.a * 2.5))
      opacity: Oracle.barAutohide ? 0.6 : 1
      clip: true
      Behavior on y { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }

      Row {
        id: row
        x: Zenon.padBar
        height: parent.height
        // none: every space is an item, as in the bar
        spacing: 0

        Repeater {
          model: bs.modules

          Item {
            id: mod
            required property var modelData
            // a divider or a gap: no module, only room (and a rule)
            readonly property bool stretch: mod.modelData.key === undefined
            readonly property bool on: !mod.stretch && !!Oracle[mod.modelData.key]
            readonly property string kind: mod.modelData.kind || (mod.modelData.word ? "word" : "glyph")
            visible: !mod.stretch || bs.spacerOn(mod.modelData)
            width: mod.modelData.div ? Zenon.gap * 2 + 1 : mod.modelData.gap !== undefined ? Zenon.gap
              : body.implicitWidth + 2 * Zenon.padModule
            height: row.height

            // a divider's rule (morpheus Divider); frameless keeps its room only
            Rectangle {
              visible: !!mod.modelData.div && !Oracle.barBare
              anchors.centerIn: parent
              width: 1
              height: parent.height
              color: Zenon.border
            }

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
                    textColor: index === 1 ? Zenon.accent
                      : Zenon.light ? Zenon.dimInk : Zenon.mix(Zenon.dimInk, Zenon.accent, 0.5)
                  }
                }
              }
              BarText {
                id: clock
                anchors.centerIn: parent
                visible: mod.kind === "clock"
                numeric: true
                src: Oracle.clock24h ? "13:00" : "1:00"
                textColor: Zenon.accent
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
