// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A LONG LIST, SEARCHED — the setup assistant's languages, cities and
// keyboard layouts, hundreds each: a dropdown would be a wall. A search
// line over a list; typing filters it, up and down move the cursor (the
// suite's sliding CursorBand), return or a click picks. The one picked
// carries a tick, and the list opens scrolled to it.
//
//     PickList {
//       model: [{ value, label, sub }]      // sub: the dim words at the right
//       current: "de_DE.UTF-8"
//       onPicked: (v) => …
//     }

import QtQuick
import "../../morpheus"
import "../../terminus" as T

FocusScope {
  id: pl

  property var model: []
  property string current: ""
  property string placeholder: "Search"
  // a filter's words matched against label, sub and value, every word
  readonly property var rows: {
    const words = pl.query.toLowerCase().split(/\s+/).filter((w) => w !== "");
    if (words.length === 0) return pl.model || [];
    return (pl.model || []).filter((r) => {
      const hay = (String(r.label) + " " + String(r.sub || "") + " " + String(r.value)).toLowerCase();
      return words.every((w) => hay.indexOf(w) >= 0);
    });
  }
  property string query: ""
  property int sel: 0
  signal picked(string value)

  // scrolled to the one worn, once the rows are in
  function reveal() {
    const i = pl.rows.findIndex((r) => r.value === pl.current);
    pl.sel = Math.max(0, i);
    if (i >= 0) list.positionViewAtIndex(i, ListView.Center);
  }
  onModelChanged: Qt.callLater(pl.reveal)
  Component.onCompleted: Qt.callLater(pl.reveal)
  function pick(i) {
    const r = pl.rows[i];
    if (!r) return;
    pl.sel = i;
    pl.picked(String(r.value));
  }

  readonly property real rowH: Zenon.px(15) * 2.3

  // ── the search line ──
  Rectangle {
    id: field
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Zenon.px(15) * 2.4
    radius: Zenon.radiusControl
    color: Zenon.wash(0.06)
    border.width: 1
    border.color: Zenon.border

    Text {
      id: lens
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      // a magnifier, as an escape (glyphs get lost in edits)
      text: "\uF002"
      color: Zenon.accentMuted
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(13)
    }
    TextInput {
      id: input
      anchors.left: lens.right
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      focus: true
      color: Zenon.white
      selectionColor: Zenon.selBg
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(15)
      clip: true
      cursorDelegate: Caret { field: input }
      onTextChanged: { pl.query = input.text; pl.sel = 0; list.positionViewAtBeginning(); }
      Keys.onUpPressed: pl.sel = Math.max(0, pl.sel - 1)
      Keys.onDownPressed: pl.sel = Math.min(pl.rows.length - 1, pl.sel + 1)
      Keys.onPressed: (e) => {
        if (e.key === Qt.Key_PageDown) { pl.sel = Math.min(pl.rows.length - 1, pl.sel + 8); e.accepted = true; }
        else if (e.key === Qt.Key_PageUp) { pl.sel = Math.max(0, pl.sel - 8); e.accepted = true; }
        // return picks the cursor's row; with nothing to pick it climbs on
        // (the assistant's Next)
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && pl.rows.length > 0
                 && pl.rows[pl.sel] && pl.rows[pl.sel].value !== pl.current) { pl.pick(pl.sel); e.accepted = true; }
        // esc clears the line first (Cynosure's rule), then climbs on
        else if (e.key === Qt.Key_Escape && input.text !== "") { input.text = ""; e.accepted = true; }
      }
    }
    Text {
      anchors.left: input.left
      anchors.verticalCenter: parent.verticalCenter
      visible: input.text === ""
      text: pl.placeholder
      color: Zenon.accentMuted
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(15)
    }
    // the suite's focus ring on a boxed field
    T.HeldRing { anchors.fill: parent; radius: parent.radius; z: 10; on: input.activeFocus }
  }

  // ── the rows ──
  Rectangle {
    id: frame
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: field.bottom
    anchors.topMargin: 10
    anchors.bottom: parent.bottom
    radius: Zenon.radiusControl
    color: Zenon.wash(0.03)
    border.width: 1
    border.color: Zenon.border
    clip: true

    ListView {
      id: list
      anchors.fill: parent
      anchors.margins: 1
      clip: true
      model: pl.rows
      boundsBehavior: Flickable.StopAtBounds
      ElasticScroll { view: list }
      CursorBand { follows: list; index: pl.sel }
      onCountChanged: if (pl.sel >= count) pl.sel = Math.max(0, count - 1)
      Connections {
        target: pl
        function onSelChanged() { list.positionViewAtIndex(pl.sel, ListView.Contain); }
      }

      delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool worn: String(row.modelData.value) === pl.current
        width: list.width
        height: pl.rowH

        Text {
          id: tick
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          width: Zenon.px(14)
          // a check mark, the worn one
          text: row.worn ? "\uF00C" : ""
          color: Zenon.accent
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(13)
        }
        Text {
          anchors.left: tick.right
          anchors.leftMargin: 10
          anchors.right: sub.left
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.label
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Zenon.white
          font.family: Zenon.face
          font.weight: row.worn ? Zenon.titleWeight : Zenon.weight
          font.pixelSize: Zenon.px(15)
        }
        Text {
          id: sub
          anchors.right: parent.right
          anchors.rightMargin: 18
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, row.width * 0.45)
          horizontalAlignment: Text.AlignRight
          text: row.modelData.sub || ""
          textFormat: Text.PlainText
          elide: Text.ElideLeft
          color: Zenon.accentMuted
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(13)
        }
        MouseArea {
          anchors.fill: parent
          onClicked: { input.forceActiveFocus(); pl.pick(row.index); }
        }
      }
    }
    // on the frame's edge, not the view's (scrollbar-hugs-edge)
    Scrollbar {
      flick: list
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
    }

    EmptyState {
      anchors.centerIn: parent
      visible: pl.rows.length === 0
      filtered: (pl.model || []).length > 0
      text: (pl.model || []).length === 0 ? "Reading the list…" : "Nothing matches “" + pl.query + "”"
    }
  }
}
