// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ── SET AS BACKGROUND ─────────────────────────────────────────────────
// A picture's "Set as background", from its menu: picasso's own setter
// (picasso/BackgroundSetter) in a sheet hanging from the bar — the same
// monitors, span, fit, look and slideshow the viewer's sheet and Quick
// Access' page offer, not a set of choices of terminus' own (user,
// 2026-10-31: the per-monitor menu rows are gone with it). Its sheet slot
// is s13.
//
// `term` is the terminus window; window items it uses are read as
// term.<id>Ref (the window's aliases).

import QtQuick
import "../morpheus"
import "../picasso"
import "terminus.js" as Terminus

Item {
  id: bgSet
  // the terminus window (`term`, never `root` — see terminus-split notes)
  property var term: null
  anchors.fill: parent
  z: 14
  visible: bgSet.open || bgSheet.cardInk > 0.01

  property bool open: false
  // the picture it is on, which the arrows change — the bar's title
  readonly property string path: bgSetter.path

  function ask(path) {
    if (!path || path === "") return;
    bgSetter.begin(path, {});
    bgSet.open = true;
    claim.begin();
  }
  function dismiss() {
    bgSet.open = false;
    term.contentRef.forceActiveFocus();
  }

  // the keys go to the setter while it is up (BackgroundSetter.key)
  FocusRetry {
    id: claim
    live: bgSet.open
    took: bgSetter.activeFocus
    onPlace: bgSetter.forceActiveFocus()
  }

  InputShield { keepTop: term.tabStripRef.height + term.crumbBarRef.height; onClicked: bgSet.dismiss() }

  TermSheet {
    host: term
    note: "s13"
    id: bgSheet
    leftInset: term.sideRef.width
    floating: false   // hangs from the bar, which carries its title — see barTitle
    title: term.sheetTitle
    glyph: term.sheetGlyph
    titleInk: term.sheetTitleInk
    glyphInk: term.sheetGlyphInk
    shown: bgSet.open
    fromTop: term.tabStripRef.height + term.crumbBarRef.height
    cardW: 980
    cardH: bgSetter.implicitHeight

    BackgroundSetter {
      id: bgSetter
      anchors.fill: parent
      shown: bgSet.open
      screen: term.screen
      // the arrows browse the pictures in the listing, everything staged kept
      list: bgSet.open ? term.view.filter((r) => !r.isDir && Terminus.isImage(r.name)) : []
      onStepped: (d) => bgSetter.path = bgSetter.list[bgSetter.index + d].path
      onDone: bgSet.dismiss()
      Keys.onPressed: (e) => { e.accepted = true; bgSetter.key(e); }
    }
  }
}
