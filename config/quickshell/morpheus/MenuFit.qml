// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// HOW WIDE A MENU CARD'S ROWS NEED IT TO BE — the one measure behind every
// fitting card (CardMenu, MenuCore/CardPopup, terminus BulkDrop), so a card
// and the dropdown face it hangs from agree to the pixel. Everything CardBody
// draws around a label is counted: its insets, a glyph or image or a theme's
// swatch and their gap, a key-cap hint, the tick or chevron, and a row set in
// a weight of its own (a font weight's menu) measured in that weight — the
// regular face's width elided "Bold" and "Black" (user, 2026-11-05).
//
//     MenuFit { id: fit; model: rows; again: menu.open }   // fit.cardW
import QtQuick
import "."

Item {
  id: fit
  visible: false

  property var model: []
  // read and nothing more: a change measures again (an opening, say)
  property var again: null

  FontMetrics {
    id: rowMetrics
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(16)
  }
  FontMetrics {
    id: hintMetrics
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(12)
  }
  // a row's own weight, 100 to 900
  Instantiator {
    id: weighed
    model: 9
    delegate: FontMetrics {
      required property int index
      font.family: Zenon.face
      font.weight: (index + 1) * 100
      font.pixelSize: Zenon.px(16)
    }
  }
  function metricsFor(w) {
    if (!w) return rowMetrics;
    const o = weighed.objectAt(Math.max(0, Math.min(8, Math.round(w / 100) - 1)));
    return o || rowMetrics;
  }

  // the rows alone, no floor: what the longest row needs, with the card's
  // label insets and border
  readonly property int rowsW: {
    fit.again;
    rowMetrics.height;   // and when the face resolves (advanceWidth is a call)
    weighed.count;
    let most = 0;
    const rows = fit.model || [];
    for (let i = 0; i < rows.length; ++i) {
      const r = rows[i];
      if (!r || r.isSeparator) continue;
      let w = fit.metricsFor(r.weight).advanceWidth(String(r.text || "")) + 12 + 10;
      if (r.swatch) w += 22 + Zenon.menuIconGap;
      else if (r.icon || r.image) w += 16 + Zenon.menuIconGap;
      // a theme's inks at the right (ThemeInks)
      if (r.inks) w += 92 + 12;
      // a dimmed choice (markDim) has no tick
      if (r.hasChildren || r.children || (r.mark !== undefined && !r.markDim)) w += 16 + 8;
      // the hint on its key cap: the cap's padding round the words (KeyCap)
      if (r.hint) w += hintMetrics.advanceWidth(String(r.hint)) + Math.round(Zenon.px(12) * 1.15) + 2 + 12;
      most = Math.max(most, w);
    }
    return Math.ceil(most + Zenon.menuCardPad * 2 + 2 + Zenon.menuFitSlack);
  }
  // the card: as wide as its rows, never under Zenon.menuMinWidth
  readonly property int cardW: Math.max(Zenon.menuMinWidth, fit.rowsW)
}
