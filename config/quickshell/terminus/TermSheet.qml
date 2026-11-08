// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A SHEET HUNG FROM TERMINUS' BAR — morpheus' Sheet as every one of the
// window's sheets wears it: clear (the listing is cut away under it, see
// sheetHole), the listing frosted under the card, the bar's frost carried
// over the seam, spliced into the bar's edge, and where it is drawn told to
// the window under `note` (TerminusCards.noteSheet), so the hole and the
// strip follow the card.
//
// Was written out in 16 sheets, nine lines each (2026-11-08).

import QtQuick
import "../morpheus"

Sheet {
  id: ts
  // the window (TerminusWindow's root)
  property var host: null
  // the key the window knows this sheet by in noteSheet: "s0", "disktool"…
  property string note: ""

  ground: "transparent"
  backdrop: ts.host ? ts.host.sheetBackdrop : null
  seamFrost: ts.host ? ts.host.sheetSeam : 0
  splice: true

  function tell() {
    if (ts.host && ts.note !== "")
      ts.host.noteSheet(ts.note, ts.cardInk, ts.drawnX, ts.drawnW, ts.drawnY, ts.drawnH);
  }
  onCardInkChanged: ts.tell()
  onDrawnXChanged: ts.tell()
  onDrawnWChanged: ts.tell()
  onDrawnYChanged: ts.tell()
  onDrawnHChanged: ts.tell()
}
