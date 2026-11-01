// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE REFUSAL SHAKE — the lock screen's, for every password field.
//
// A rejected password shoves the field aside rather than just swapping a
// glyph; it is the one interaction that has to be felt without being read.
// A transform, so it moves the field without fighting its anchors:
//
//   transform: Shake { id: shake }
//   ... shake.run()
//
// `reach` is the first swing in pixels; the rest of the swing keeps the
// lock's proportions (11, -11, 7, -4, 0).

import QtQuick

Translate {
  id: shake
  property real reach: 11
  function run() { anim.restart(); }

  property SequentialAnimation anim: SequentialAnimation {
    NumberAnimation { target: shake; property: "x"; to:  shake.reach;               duration: Zenon.ms(55); easing.type: Easing.OutSine }
    NumberAnimation { target: shake; property: "x"; to: -shake.reach;               duration: Zenon.ms(90); easing.type: Easing.InOutSine }
    NumberAnimation { target: shake; property: "x"; to:  shake.reach * 7 / 11;      duration: Zenon.ms(80); easing.type: Easing.InOutSine }
    NumberAnimation { target: shake; property: "x"; to: -shake.reach * 4 / 11;      duration: Zenon.ms(70); easing.type: Easing.InOutSine }
    NumberAnimation { target: shake; property: "x"; to:  0;                         duration: Zenon.ms(60); easing.type: Easing.OutSine }
  }
}
