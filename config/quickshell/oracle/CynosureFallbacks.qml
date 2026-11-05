// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE OTHER WAYS, unfolded — Cynosure › Search (2026-11-04, Raycast's
// fallback commands). What is offered under the matches when you type, in
// Muted apps' frame: each way's Check (offered or not), its name and the
// app it is, and a chevron up and down to move it. Every change is
// Oracle.set("cynosureFallbackList"), through Cynosure.fallbackSet/Moved.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "../morpheus"
import "../morpheus/controls" as Controls
import "../cynosure/cynosure.js" as Cy

Item {
  id: cf
  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  readonly property var ways: Cy.fallbackList(Oracle.cynosureFallbackList)
  function put(text) { Oracle.set("cynosureFallbackList", text); }

  implicitHeight: frame.height + 24

  Item {
    id: frame
    x: 24
    y: 6
    width: cf.width - 48
    height: list.implicitHeight + 12
    Controls.ListFrame { anchors.fill: parent }

    Column {
      id: list
      x: 6
      y: 6
      width: parent.width - 12

      Repeater {
        model: cf.ways
        delegate: Item {
          id: way
          required property var modelData
          required property int index
          width: list.width
          height: 34

          Controls.Check {
            id: onBox
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            lit: way.modelData.on
            ink: cf.highlight
            onToggled: cf.put(Cy.fallbackSet(Oracle.cynosureFallbackList, way.modelData.word, !way.modelData.on))
          }
          Text {
            id: glyph
            textFormat: Text.PlainText
            anchors.left: onBox.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Zenon.px(22)
            horizontalAlignment: Text.AlignHCenter
            text: Cy.fallbackGlyph(way.modelData.glyph)
            color: way.modelData.on ? cf.fgColor : cf.dimColor
            font.family: cf.face
            font.pixelSize: Zenon.px(15)
          }
          Text {
            textFormat: Text.PlainText
            anchors.left: glyph.right
            anchors.leftMargin: 10
            anchors.right: sub.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: way.modelData.name
            color: way.modelData.on ? cf.fgColor : cf.dimColor
            font.family: cf.face
            font.pixelSize: Zenon.px(16)
          }
          Text {
            id: sub
            textFormat: Text.PlainText
            anchors.right: moves.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: way.modelData.sub
            color: cf.dimColor
            font.family: cf.face
            font.pixelSize: Zenon.px(13)
          }
          Row {
            id: moves
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            // the fold's chevron, turned: up, then down
            Item {
              width: upChip.width
              height: upChip.height
              rotation: -90
              opacity: way.index > 0 ? 1 : Zenon.disabledDim
              ChevronChip {
                id: upChip
                size: Zenon.px(14)
                onClicked: if (way.index > 0) cf.put(Cy.fallbackMoved(Oracle.cynosureFallbackList, way.modelData.word, -1))
              }
            }
            Item {
              width: downChip.width
              height: downChip.height
              rotation: 90
              opacity: way.index < cf.ways.length - 1 ? 1 : Zenon.disabledDim
              ChevronChip {
                id: downChip
                size: Zenon.px(14)
                onClicked: if (way.index < cf.ways.length - 1) cf.put(Cy.fallbackMoved(Oracle.cynosureFallbackList, way.modelData.word, 1))
              }
            }
          }
        }
      }
    }
  }
}
