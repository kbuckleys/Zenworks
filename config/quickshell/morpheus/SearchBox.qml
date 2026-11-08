// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SUITE'S ONE SEARCH FIELD (user, 2026-11-07): terminus' BulkField with
// the lens, the clear chip and one size. 34 at the head of a list, `compact`
// 28 in a row beside buttons.
//
//     SearchBox {
//       ghost: "Search notes"
//       onTextChanged: win.query = text
//       keyHook: (e) => { if (win.navKey(e)) e.accepted = true; }
//     }
//
// Keys a caller wants before the text does go through `keyHook` (or `keysTo`,
// to forward to an item); keys the text leaves alone, like Escape and the
// arrows up and down, also reach a plain Keys handler on the SearchBox itself.
// Return is `accepted` unless the hook took it. A launcher's always-focused
// line is not one of these: it has no box to ring.

import QtQuick
import "../terminus" as Term

Term.BulkField {
  property bool compact: false
  height: compact ? 28 : 34
  textSize: Zenon.px(compact ? 14 : 15)
  radius: Zenon.windowRadius
  color: Zenon.wash(0.06)
  lens: "\uF002"
  clearable: true
  refocusOnClear: true
}
