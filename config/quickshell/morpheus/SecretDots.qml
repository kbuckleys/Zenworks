// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A PASSWORD, AS DOTS — the lock screen's, for every password field.
//
// Moved out of cerberus (2026-10-31) so ceres' PasswordField and every
// masked BulkField type the way the lock does: each dot slides in from the
// left with one OutBack overshoot while it fades and grows in, and the whole
// row swells and settles on every keystroke, Backspace too, so the feedback
// carries even when one more dot at the end of a long row is easy to miss.
// A deleted dot simply goes.
//
// Only the COUNT is handed in; the characters never reach this item. The
// holder sizes, inks and fades it — the lock's row fades with its phase.

import QtQuick

Row {
  id: dots
  // how many characters are typed — every change kicks the row, even one
  // past `max` that adds no dot
  property int count: 0
  // as many as fit, never more (ceres' field keeps a long passphrase inside)
  property int max: 100000
  // U+F09DE, past the BMP, so a literal character: QML's string lexer takes
  // only the four-digit \u form, and "E" reads as U+F09D then "E"
  property string glyph: "󰧞"
  property color ink: Zenon.ink
  property string family: Zenon.face
  property int weight: Zenon.weight
  property real size: Zenon.px(15)

  // the swell on each keystroke
  property real kick: 1
  scale: dots.kick
  transformOrigin: Item.Center

  SequentialAnimation {
    id: kickAnim
    NumberAnimation { target: dots; property: "kick"; to: 1.10; duration: Zenon.ms(85); easing.type: Easing.OutQuad }
    NumberAnimation { target: dots; property: "kick"; to: 1.0;  duration: Zenon.ms(260); easing.type: Easing.OutCubic }
  }
  onCountChanged: if (dots.count > 0) kickAnim.restart()

  Repeater {
    model: Math.min(dots.count, dots.max)

    delegate: Text {
      id: dot
      required property int index
      text: dots.glyph
      color: dots.ink
      font.family: dots.family
      font.weight: dots.weight
      font.pixelSize: dots.size

      // A Translate, so the Row's own x layout is not fought.
      property real tx: -dots.size * 0.85
      transform: Translate { x: dot.tx }
      scale: 0.7
      opacity: 0
      Component.onCompleted: {
        Qt.callLater(() => {
          dot.scale = 1;
          dot.opacity = 1;
          dot.tx = 0;
        });
      }
      Behavior on scale {
        NumberAnimation { duration: Zenon.ms(300); easing.type: Easing.OutBack; easing.overshoot: 1.4 }
      }
      Behavior on opacity { NumberAnimation { duration: Zenon.ms(150); easing.type: Easing.OutQuad } }
      Behavior on tx {
        NumberAnimation { duration: Zenon.ms(320); easing.type: Easing.OutBack; easing.overshoot: 1.3 }
      }
    }
  }
}
