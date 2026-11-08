// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SETUP ASSISTANT'S APPS — two yes-or-no questions, each asked only
// while it is still open, both opt-in:
//
//   Flathub     Ceres' own setup question (Ceres.flatpakAsk), answered
//               here: yes is "want", asked again where Ceres fetches
//               flatpak with its box ticked; no is never asked again
//   Terminal    Zenworks' zsh setup (ZshSetup), done after the other jobs;
//               no is an answer, so its notification never comes
//
// Nothing happens on a tick: the assistant does it after Finish.

import QtQuick
import "../../morpheus"
import "../../morpheus/controls" as Controls
import "../../ceres"
import ".."

Item {
  id: step
  // the assistant; not `asst`, which shadowed its id and bound to itself
  property var setup: null

  readonly property bool askFlatpak: Ceres.flatpakAsk
  readonly property bool askZsh: Oracle.zshAnswer !== "yes"

  Column {
    width: parent.width
    spacing: 10

    Repeater {
      model: [
        { key: "flatpak", on: step.askFlatpak, title: "Flathub apps in the Store",
          words: "Ceres shows Flathub's sandboxed apps beside Arch's and the AUR's. Flatpak is installed when Ceres first sets up." },
        { key: "zsh", on: step.askZsh, title: "Zenworks' terminal setup",
          words: "zsh with a fast prompt, suggestions and fuzzy completion. Your current setup is kept as a backup." }
      ].filter((q) => q.on)
      delegate: Rectangle {
        id: q
        required property var modelData
        readonly property bool lit: q.modelData.key === "flatpak" ? step.setup.wantFlatpak : step.setup.wantZsh
        function flip() {
          if (q.modelData.key === "flatpak") step.setup.wantFlatpak = !step.setup.wantFlatpak;
          else step.setup.wantZsh = !step.setup.wantZsh;
        }
        width: parent.width
        height: col.implicitHeight + 28
        radius: Zenon.radiusCard
        color: q.lit ? Zenon.alpha(Zenon.accent, 0.14) : Zenon.wash(0.04)
        border.width: 1
        border.color: q.lit ? Zenon.accent : Zenon.border
        Behavior on color { ColorAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }

        Controls.Check {
          id: box
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          lit: q.lit
          // the card's tap takes a tap on the box too: one answer
          enabled: false
          held: tap.pressed
        }
        Column {
          id: col
          anchors.left: box.right
          anchors.leftMargin: 14
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Text {
            text: q.modelData.title
            textFormat: Text.PlainText
            color: q.lit ? Zenon.accent : Zenon.white
            font.family: Zenon.face
            font.weight: Zenon.titleWeight
            font.pixelSize: Zenon.px(15)
          }
          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: q.modelData.words
            textFormat: Text.PlainText
            color: Zenon.accentMuted
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(13)
          }
        }
        MouseArea {
          id: tap
          anchors.fill: parent
          onClicked: q.flip()
        }
      }
    }

    EmptyState {
      width: parent.width
      visible: !step.askFlatpak && !step.askZsh
      text: "Both are set up already."
    }
  }
}
