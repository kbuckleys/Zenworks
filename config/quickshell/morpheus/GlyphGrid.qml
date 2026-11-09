// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// GLYPHGRID — a face's characters as a grid of cells, with the search over
// their names on top: Alexandria's Glyphs page, and terminus' Change glyph…
// sheet (2026-11-05: moved here out of AlexandriaWindow so the sheet is the
// same grid, not a second one).
//
// It draws and takes the pointer; what it walks and what a key does are the
// owner's:
//   index      the cells (alexandria.js indexOf / indexOfList)
//   total      how many there are before a search, for the count
//   query      the search's words; the owner searches (A.searchGlyphs)
//   sel        the cell the cursor is on
//   cell       a cell's size; family/styleName the face drawn in
//   navKey(e)  every key the field gets, first (true = taken)
//   zoom(d)    ctrl + wheel, when given
//   busy       the characters are still being read (no empty state yet)
//   chose(i, alt)   a click (alt: right button or shift)
//   used(i)         a double click
//   field, grid     for focus and positionViewAtIndex

import QtQuick
import "../alexandria/alexandria.js" as A

Item {
  id: gg

  property var index: A.indexOf([])
  property int total: 0
  property string query: ""
  property int sel: 0
  property int cell: 64
  property string family: Zenon.glyphFace
  property string styleName: ""
  property color hiFill: Zenon.alpha(Zenon.accent, 0.12)
  property bool busy: false
  property string placeholder: "Search by name, codepoint or character — file, U+F031, →"
  property var navKey: null
  property var zoom: null
  property real edge: 14
  signal chose(int i, bool alt)
  signal used(int i)

  readonly property alias field: glyphField
  readonly property alias grid: glyphGrid
  readonly property int cols: glyphGrid.cols
  // the code under the cursor
  readonly property int cp: A.codeAt(gg.index, gg.sel)

  function show(i) { glyphGrid.positionViewAtIndex(i, GridView.Contain); }
  // the model is empty while hidden, so a show() asked before the first
  // frame lands on nothing: seat the cursor again once there is a grid
  onVisibleChanged: if (gg.visible) Qt.callLater(() => gg.show(gg.sel))

  // the search over names and codepoints
  SearchBox {
    id: glyphField
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: gg.edge
    ghost: gg.placeholder
    trailRoom: glyphCount.width + 10
    Component.onCompleted: glyphField.text = gg.query
    // set, not bound: the × and the text would each have broken a binding
    Connections {
      target: gg
      function onQueryChanged() { if (glyphField.text !== gg.query) glyphField.text = gg.query; }
    }
    onTextChanged: if (gg.query !== text) gg.query = text
    keyHook: (e) => { if (gg.navKey && gg.navKey(e)) e.accepted = true; }
    Text {
      id: glyphCount
      anchors.right: parent.right
      anchors.rightMargin: glyphField.chipRoom
      anchors.verticalCenter: parent.verticalCenter
      text: gg.index.count === gg.total ? gg.total + " glyphs" : gg.index.count + " of " + gg.total
      color: Zenon.accentMuted
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.features: { "tnum": 1 }
      font.pixelSize: Zenon.px(12)
    }
  }

  GridView {
    id: glyphGrid
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: glyphField.bottom
    anchors.bottom: parent.bottom
    anchors.topMargin: 10
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // THE LEFT MARGIN IS INSIDE THE VIEW, not an anchor margin: the
    // frost under the chrome is as wide as the view, and a view set in
    // by 14 left a 14px column of the head unfrosted. The cells are laid
    // over width − pad and moved right by it (each delegate's Translate).
    readonly property real pad: gg.edge
    readonly property int cols: Math.max(1, Math.floor((width - pad) / gg.cell))
    readonly property real cw: Math.max(1, (width - pad) / cols)
    cellWidth: cw
    // the glyph, and its codepoint line under it at the Font size
    cellHeight: gg.cell + 6 + Zenon.px(10)
    cacheBuffer: 600
    // only while shown: a hidden grid still built a screenful of cells
    model: gg.visible ? gg.index.count : 0
    delegate: Item {
      id: gcell
      required property int index
      readonly property int cp: A.codeAt(gg.index, gcell.index)
      readonly property bool here: gcell.index === gg.sel
      width: glyphGrid.cellWidth
      height: glyphGrid.cellHeight
      transform: Translate { x: glyphGrid.pad }
      Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Zenon.windowRadius
        color: gcell.here ? gg.hiFill : gMa.pressed ? Zenon.pressWash(0.12) : Zenon.wash(0.02)
        border.width: gcell.here ? 1 : 0
        border.color: Zenon.alpha(Zenon.accent, 0.7)
      }
      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        height: gg.cell - 4
        verticalAlignment: Text.AlignVCenter
        text: A.charOf(gcell.cp)
        color: Zenon.ink
        font.family: gg.family
        font.styleName: gg.styleName
        font.weight: Zenon.weight
        font.pixelSize: Math.round(gg.cell * 0.52)
      }
      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: A.hex(gcell.cp)
        color: gcell.here ? Zenon.accent : Zenon.accentMuted
        font.family: Zenon.faceMono
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(10)
      }
      MouseArea {
        id: gMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => {
          gg.sel = gcell.index;
          gg.chose(gcell.index, m.button === Qt.RightButton || !!(m.modifiers & Qt.ShiftModifier));
        }
        onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) gg.used(gcell.index); }
      }
    }
    EmptyState {
      anchors.centerIn: parent
      visible: glyphGrid.count === 0 && !gg.busy
      filtered: gg.query !== ""
    }
  }
  ElasticScroll {
    anchors.fill: glyphGrid
    view: glyphGrid
    intercept: (w) => {
      if (!gg.zoom || !(w.modifiers & Qt.ControlModifier)) return false;
      gg.zoom(w.angleDelta.y > 0 ? 1 : -1);
      return true;
    }
  }
  Scrollbar { flick: glyphGrid; anchors.right: glyphGrid.right; anchors.top: glyphGrid.top; anchors.bottom: glyphGrid.bottom }
}
