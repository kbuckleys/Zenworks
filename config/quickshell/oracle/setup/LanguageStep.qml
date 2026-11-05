// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SETUP ASSISTANT'S LANGUAGE — the system's locale, from glibc's list
// (oracle/locales.sh), in English names so "german" finds it. Picked, it is
// kept: the assistant sets it at the end with the time zone, one password
// card (SetupAssistant.applySystem). It applies from the next login.
//
// AND TEXT IN PICTURES IN IT (user, 2026-11-04): the language worn or
// picked has tesseract data (tesseract-data-deu …) not installed — English
// is the package's own — so it asks, ticked: installed through Ceres after
// Get started, and every reader (Picasso, Clio, Cynosure) uses it.

import QtQuick
import "../../morpheus"
import "../../morpheus/controls" as Controls

Item {
  id: step
  // the assistant; not `asst`, which shadowed its id and bound to itself
  property var setup: null

  Component.onCompleted: if (step.setup.locales.length === 0) step.setup.localeRead()

  PickList {
    id: list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: tess.visible ? tess.top : note.top
    anchors.bottomMargin: 12
    focus: true
    placeholder: "Search languages and countries"
    model: step.setup.locales
    current: step.setup.pickLocale !== "" ? step.setup.pickLocale : step.setup.localeNow
    onPicked: (v) => step.setup.pickLocale = v === step.setup.localeNow ? "" : v
    Component.onCompleted: forceActiveFocus()
  }

  Rectangle {
    id: tess
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: note.top
    anchors.bottomMargin: 12
    visible: step.setup.tessNeeded
    readonly property bool lit: step.setup.wantTess
    height: tessCol.implicitHeight + 24
    radius: Zenon.radiusCard
    color: tess.lit ? Qt.rgba(Zenon.accent.r, Zenon.accent.g, Zenon.accent.b, 0.14) : Zenon.wash(0.04)
    border.width: 1
    border.color: tess.lit ? Zenon.accent : Zenon.border
    Behavior on color { ColorAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
    Controls.Check {
      id: tessBox
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      lit: tess.lit
      // the card's tap takes a tap on the box too: one answer
      enabled: false
      held: tessTap.pressed
    }
    Column {
      id: tessCol
      anchors.left: tessBox.right
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text {
        text: "Read " + step.setup.tessLanguage + " text in pictures"
        textFormat: Text.PlainText
        color: tess.lit ? Zenon.accent : Zenon.white
        font.family: Zenon.face
        font.weight: Font.Bold
        font.pixelSize: Zenon.px(15)
      }
      Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "Installs " + step.setup.tessFor + ", so Picasso, Clio and Cynosure copy " + step.setup.tessLanguage + " text out of pictures as well as English."
        textFormat: Text.PlainText
        color: Zenon.muted
        font.family: Zenon.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(13)
      }
    }
    MouseArea {
      id: tessTap
      anchors.fill: parent
      onClicked: step.setup.wantTess = !step.setup.wantTess
    }
  }

  Text {
    id: note
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    wrapMode: Text.Wrap
    text: step.setup.pickLocale !== ""
      ? "Set when you get started, with your password. It applies from the next login."
      : "Leave it as it is, or pick another."
    color: Zenon.soft
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(13)
  }
}
