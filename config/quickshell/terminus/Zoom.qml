// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// Terminus' zoom … logic, out of TerminusWindow.qml
// (2026-10-08). The state stays on the window (term); the window keeps a
// one-line forwarder for each function here, so callers are unchanged.

import QtQuick

Item {
  id: zoom
  property var term: null

  // the text zoom (list, columns)
  function zoomClamp(v) {
    return Math.max(term.zoomMin, Math.min(term.zoomMax, v));
  }
  // the grid's, which goes smaller (term.thumbZoomMin); rounded to the
  // 0.1 notch's hundredths so steps from 0.7 land on 0.4 exactly
  function thumbClamp(v) {
    return Math.round(Math.max(term.thumbZoomMin, Math.min(term.zoomMax, v)) * 100) / 100;
  }
  function zoomBy(step) {
    if (term.viewMode === "grid") term.act.zoom = term.thumbClamp(term.thumbZoom + step);
    else term.zoom = term.zoomClamp(term.zoom + step);
    Qt.callLater(term.positionSel);
  }
  function zoomReset() {
    if (term.viewMode === "grid") term.act.zoom = term.thumbZoomDefault;
    else term.zoom = 1.0;
    Qt.callLater(term.positionSel);
  }
  // Straight to a value, for the settings panel's slider — the keys step, and
  // stepping is the wrong gesture when the whole range is drawn in front of
  // you. Which zoom it lands on follows the same rule zoomBy uses: the grid
  // scales its pictures, everything else scales its text, and the two are
  // deliberately independent.
  function setZoom(v) {
    if (term.viewMode === "grid") term.act.zoom = term.thumbClamp(v);
    else term.zoom = term.zoomClamp(v);
    Qt.callLater(term.positionSel);
  }
}
