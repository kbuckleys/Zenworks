// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// MUTED APPS, unfolded — Notifications' row (2026-11-03).
//
// The apps Howler holds back, in the Startup apps fold's frame: each one's
// name, Muted or Blocked to switch between, and an × that lets it through
// again. They are added from a notification's right-click menu in the bell
// (HowlerPopup's row menu); every change is Oracle.setSource. See Ora's
// NOTIFICATION SOURCES. A name is whatever the app sent, so it is plain text.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "oracle.js" as Ora
import "../morpheus"
import "../morpheus/controls" as Controls
import "../terminus" as T

Item {
  id: ns
  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  readonly property var sources: (Oracle.revision, Ora.parseSources(Oracle.notifSources))

  implicitHeight: frame.height + 24

  Item {
    id: frame
    x: 24
    y: 6
    width: ns.width - 48
    height: ns.sources.length ? list.implicitHeight + 12 : 72
    Controls.ListFrame { anchors.fill: parent }

    EmptyState {
      anchors.centerIn: parent
      width: parent.width - 40
      visible: ns.sources.length === 0
      text: "No muted apps. Right-click a notification in the bell to mute or block its app."
    }

    Column {
      id: list
      x: 6
      y: 6
      width: parent.width - 12
      visible: ns.sources.length > 0

      Repeater {
        model: ns.sources
        delegate: Item {
          id: src
          required property var modelData
          width: list.width
          height: 34

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: stateSegs.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: src.modelData.name
            color: src.modelData.state === "block" ? ns.dimColor : ns.fgColor
            font.family: ns.face
            font.pixelSize: Zenon.px(16)
          }
          T.Segments {
            id: stateSegs
            anchors.right: drop.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            options: [["mute", "Muted"], ["block", "Blocked"]]
            current: src.modelData.state
            onChose: (v) => Oracle.setSource(src.modelData.name, v)
          }
          ClearChip {
            id: drop
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            size: Zenon.px(14)
            onClicked: Oracle.setSource(src.modelData.name, "")
          }
        }
      }
    }
  }
}
