// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SETUP ASSISTANT'S ACCOUNTS — all optional, here for convenience
// (user, 2026-11-04). Each row opens its app's own place for accounts, so
// nothing about signing in is written twice: Chronos' online accounts
// sheet (CalDAV), Delphi's Accounts page (GitHub, GitLab, Codeberg),
// Calypso's window (a password manager to connect). The card steps aside
// while the app is up and comes back when its window closes.

import QtQuick
import "../../morpheus"

Item {
  id: step
  // the assistant; not `asst`, which shadowed its id and bound to itself
  property var setup: null

  readonly property var rows: [
    { glyph: "\uF073", name: "Calendar", words: "Your calendars over CalDAV (Nextcloud, iCloud, Fastmail…), in Chronos.",
      title: "chronos", ipc: ["Calendar", "accounts"] },
    { glyph: "\uF1D3", name: "Git forges", words: "GitHub, GitLab or Codeberg, for Delphi's repositories, pull requests and releases.",
      title: "delphi", ipc: ["Delphi", "accounts"] },
    { glyph: "\uF084", name: "Passwords", words: "Bitwarden, 1Password, KeePass or pass, in Calypso.",
      title: "calypso", ipc: ["Calypso", "open"] }
  ]

  Column {
    width: parent.width
    spacing: 10

    Repeater {
      model: step.rows
      delegate: Rectangle {
        id: row
        required property var modelData
        width: parent.width
        height: Math.max(words.implicitHeight + name.implicitHeight + 30, addBtn.height + 24)
        radius: Zenon.radiusCard
        color: Zenon.wash(0.04)
        border.width: 1
        border.color: Zenon.border

        Text {
          id: badge
          anchors.left: parent.left
          anchors.leftMargin: 18
          anchors.verticalCenter: parent.verticalCenter
          width: Zenon.px(20)
          horizontalAlignment: Text.AlignHCenter
          text: row.modelData.glyph
          color: Zenon.soft
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(18)
        }
        Column {
          anchors.left: badge.right
          anchors.leftMargin: 14
          anchors.right: addBtn.left
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Text {
            id: name
            text: row.modelData.name
            textFormat: Text.PlainText
            color: Zenon.white
            font.family: Zenon.face
            font.weight: Zenon.titleWeight
            font.pixelSize: Zenon.px(15)
          }
          Text {
            id: words
            width: parent.width
            wrapMode: Text.Wrap
            text: row.modelData.words
            textFormat: Text.PlainText
            color: Zenon.accentMuted
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(13)
          }
        }
        DialogButton {
          id: addBtn
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          label: "Add…"
          onClicked: step.setup.visit(step.setup.windowUp(row.modelData.title), row.modelData.ipc)
        }
      }
    }
  }
}
