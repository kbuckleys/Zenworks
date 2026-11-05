// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SETUP ASSISTANT'S LAST STEP — what Get started does next, in order: the
// shortcuts sheet, then the password asked once for what was kept (the
// language, the time zone), then the terminal setup. And where each choice
// lives afterwards, in Oracle.

import QtQuick
import "../../morpheus"
import ".."
import "../oracle.js" as Ora

Item {
  id: step
  // the assistant; not `asst`, which shadowed its id and bound to itself
  property var setup: null

  readonly property var next: {
    const chord = Ora.chordCaps(Oracle.keyValues["bind:keysSheet"] || "").join(" + ");
    const out = [["\uF11C", "The shortcuts come next." + (chord !== "" ? " " + chord + " brings them back any time." : "")]];
    const sys = [];
    if (step.setup.pickLocale !== "") sys.push("language");
    if (step.setup.pickZone !== "") sys.push("time zone");
    if (sys.length > 0)
      out.push(["\uF084", "Then your password, once, to set the " + sys.join(" and ") + "."
        + (step.setup.pickLocale !== "" ? " The language applies from the next login." : "")]);
    if (step.setup.tessWanted)
      out.push(["\uF02B", "Then " + step.setup.tessLanguage + " text recognition (" + step.setup.tessFor + ")."]);
    if (step.setup.wantZsh) out.push(["\uF120", "Then the terminal setup, which may ask for your password too."]);
    if (step.setup.wantFlatpak) out.push(["\uF1B3", "Flathub comes with Ceres' first setup."]);
    out.push(["\uF013", "Everything you chose stays in Oracle: Appearance, Keyboard, Time & date and Fonts."]);
    return out;
  }

  Column {
    width: parent.width
    spacing: 14
    Repeater {
      model: step.next
      delegate: Row {
        id: line
        required property var modelData
        width: parent.width
        spacing: 14
        Text {
          width: Zenon.px(20)
          horizontalAlignment: Text.AlignHCenter
          text: line.modelData[0]
          textFormat: Text.PlainText
          color: Zenon.accent
          font.family: Zenon.face
          font.pixelSize: Zenon.px(16)
        }
        Text {
          width: line.width - Zenon.px(20) - line.spacing
          wrapMode: Text.Wrap
          text: line.modelData[1]
          textFormat: Text.PlainText
          color: Zenon.soft
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(15)
        }
      }
    }
  }
}
