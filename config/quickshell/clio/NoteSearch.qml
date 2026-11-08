// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SEARCH OVER CLIO'S LIST — every word somewhere, and Apple's tokens
// (#tag, is:pinned, has:checklist…), offered as chips while it is empty and
// focused. Typing in the list lands here; Esc clears it, then hands the
// keys back.

import QtQuick
import "../morpheus"

Item {
  id: bar
  property var win: null
  function grab() { searchField.forceActiveFocus(); searchField.selectAll(); }
  function type(t) { searchField.text += t; searchField.forceActiveFocus(); }
  function clear() { searchField.text = ""; }
  Connections { target: bar.win; function onQueryChanged() { if (searchField.text !== bar.win.query) searchField.text = bar.win.query; } }

  HeadGround {}

  SearchBox {
    id: searchField
    anchors.left: parent.left
    anchors.right: newBtn.left
    anchors.rightMargin: 8
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    ghost: !bar.win ? "" : bar.win.inJournal ? "Search entries" : bar.win.onDesktop ? "Search stickies" : "Search notes"
    onTextChanged: if (bar.win && bar.win.query !== text) { bar.win.query = text; bar.win.wantTop = true; }
    keyHook: (e) => {
      if (e.key === Qt.Key_Escape) {
        if (searchField.text !== "") searchField.text = "";
        else bar.win.refocus();
        e.accepted = true;
        return;
      }
      if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) { bar.win.move(e.key === Qt.Key_Down ? 1 : -1); e.accepted = true; return; }
      if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { bar.win.paneRef.focusEditor(false); e.accepted = true; }

    }
  }

  // a new note (or entry, or sticky) where you are
  DialogButton {
    id: newBtn
    anchors.right: setBtn.left
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    // the search field's height, and square (user, 2026-10-17)
    height: searchField.height
    width: searchField.height
    glyph: true
    label: ""
    // the theme's accent, as the other windows' primary actions (user, 10-21)
    ink: Zenon.accent
    onClicked: bar.win.inJournal ? bar.win.newEntry() : bar.win.newNote()
    // a right click: from a template
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      onClicked: (m) => { if (bar.win.onDesktop) return; const p = mapToItem(bar.win.stageItem, m.x, m.y); bar.win.templateMenu(p.x, p.y); }
    }
    HoverHandler {
      onHoveredChanged: hovered
        ? bar.win.tipsItem.show(newBtn, bar.win.inJournal ? "New entry" : bar.win.onDesktop ? "New sticky" : "New note", bar.win.inJournal ? "ctrl j" : "ctrl n")
        : bar.win.tipsItem.hide(newBtn)
    }
  }

  // settings, beside it (user, 2026-11-02: off the sidebar, whose name
  // went with it) — the same square, in the plain ink
  DialogButton {
    id: setBtn
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    height: searchField.height
    width: searchField.height
    glyph: true
    label: "\u{F08BB}"
    // pressed for as long as its sheet is up (user, 2026-11-02)
    held: !!bar.win && bar.win.setOpen
    onClicked: bar.win.setOpen = true
    HoverHandler {
      onHoveredChanged: hovered ? bar.win.tipsItem.show(setBtn, "Settings", "ctrl ,") : bar.win.tipsItem.hide(setBtn)
    }
  }

  // the tokens, offered while the search is empty and has the keys
  //
  // A MENU INSIDE A WINDOW (2026-10-22): it was tipBg, a frosted ground, but
  // nothing frosts what is behind an item in Clio's own window — the list's
  // heading, its day label and the first note showed sharp through the
  // chips. Solid and shadowed, as terminus' right-click menu is.
  MenuShadow {
    panel: tokenCard
    visible: tokenCard.visible
    z: 19
  }
  Rectangle {
    id: tokenCard
    visible: searchField.activeFocus && searchField.text === "" && !bar.win.onDesktop
    z: 20
    anchors.top: searchField.bottom
    anchors.topMargin: 6
    anchors.left: searchField.left
    width: searchField.width + 44
    height: tokens.implicitHeight + 20
    radius: Zenon.menuRadius
    color: Zenon.menuBgSolid
    border.width: 1
    border.color: Zenon.border
    Flow {
      id: tokens
      x: 10
      y: 10
      width: parent.width - 20
      spacing: 6
      Repeater {
        model: bar.win && bar.win.inJournal
          ? ["is:bookmarked", "has:photo", "has:mood", "has:checklist"]
          : ["is:pinned", "is:todo", "is:done", "is:locked", "has:checklist", "has:picture", "has:file", "has:table", "has:sketch", "has:link"]
        delegate: Rectangle {
          required property string modelData
          width: tk.implicitWidth + 16
          height: 24
          radius: Zenon.windowRadius
          color: Zenon.wash(0.06)
          border.width: 1
          border.color: Zenon.border
          Text {
            id: tk
            anchors.centerIn: parent
            text: modelData
            color: Zenon.accentSoft
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(12)
          }
          MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; searchField.text = modelData + " "; searchField.forceActiveFocus(); searchField.cursorPosition = searchField.text.length; }
          }
        }
      }
    }
  }
}
