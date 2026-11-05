// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// HIDDEN FROM THE LIST, unfolded — Cynosure › Search (2026-11-04, Raycast's
// disabled commands). The apps, commands and quick links you hid with
// Ctrl+K › Hide, in Muted apps' frame: each one's name and an × that puts it
// back. Every change is Oracle.set("cynosureHidden"), Cynosure.withHidden.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "../morpheus"
import "../morpheus/controls" as Controls
import "../cynosure/cynosure.js" as Cy

Item {
  id: ch
  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  readonly property var hidden: Cy.parseHidden(Oracle.cynosureHidden)
  readonly property var kinds: ({ app: "App", shell: "Command", link: "Quick link" })

  implicitHeight: frame.height + 24

  Item {
    id: frame
    x: 24
    y: 6
    width: ch.width - 48
    height: ch.hidden.length ? list.implicitHeight + 12 : 72
    Controls.ListFrame { anchors.fill: parent }

    EmptyState {
      anchors.centerIn: parent
      width: parent.width - 40
      visible: ch.hidden.length === 0
      text: "Nothing hidden. Ctrl+K on an app, a command or a quick link in Cynosure, then Hide."
    }

    Column {
      id: list
      x: 6
      y: 6
      width: parent.width - 12
      visible: ch.hidden.length > 0

      Repeater {
        model: ch.hidden
        delegate: Item {
          id: one
          required property var modelData
          width: list.width
          height: 34

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: kind.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: one.modelData.name
            color: ch.fgColor
            font.family: ch.face
            font.pixelSize: Zenon.px(16)
          }
          Text {
            id: kind
            textFormat: Text.PlainText
            anchors.right: drop.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: ch.kinds[one.modelData.id.split(":")[0]] || ""
            color: ch.dimColor
            font.family: ch.face
            font.pixelSize: Zenon.px(13)
          }
          ClearChip {
            id: drop
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            size: Zenon.px(14)
            onClicked: Oracle.set("cynosureHidden", Cy.withHidden(Oracle.cynosureHidden, one.modelData.id, "", false))
          }
        }
      }
    }
  }
}
