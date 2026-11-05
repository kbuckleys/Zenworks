// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE DESKTOP MENU PAGE'S MENU (user, 2026-11-03: more pictures in oracle):
// icarus' root card as a right click on the desktop opens it, with Home's
// card hung off its row — the suite's own card (morpheus/CardBody), so Row
// height is drawn at its real size and each card as wide as its rows, and the Entries and
// Home rows below take their rows away or put them back as they change.
// The rows are icarus' own words and glyphs (IcarusPopup's rows and
// shellEntries); a pointer stands where the click was.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import "../morpheus"

Item {
  id: sample

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  // the row the pointer is on; Home's while nothing is pointed at, so its
  // card has a row to hang from
  property int hoverAt: -1

  // icarus' root rows, in its order, rules only between groups that are there
  readonly property var rootRows: {
    const rows = [];
    const sep = () => {
      if (rows.length === 0 || rows[rows.length - 1].isSeparator) return;
      rows.push({ isSeparator: true, enabled: false });
    };
    if (Oracle.menuShowFiles) rows.push({ text: "Files", icon: "" });
    if (Oracle.menuShowRecent) rows.push({ text: "Recent", icon: "", hasChildren: true });
    sep();
    if (Oracle.menuShowApps) rows.push({ text: "Apps", icon: "", hasChildren: true });
    if (Oracle.menuShowHome) rows.push({ id: "home", text: "Home", icon: "", hasChildren: true });
    if (Oracle.menuShowTrash) rows.push({ text: "Trash", icon: "", enabled: false });
    sep();
    // Hide notes stands for Hide/Show notes (only there once a note is)
    if (Oracle.menuShowNote) rows.push({ text: "Hide notes", icon: "\uF070" });
    if (Oracle.menuShowNote) rows.push({ text: "New sticky note", icon: "" });
    if (Oracle.menuShowBackground) rows.push({ text: "Set background", icon: "" });
    if (Oracle.menuShowDisplay) rows.push({ text: "Display settings", icon: "" });
    sep();
    if (Oracle.menuShowPackages) rows.push({ text: "Store", icon: "󰵨" });
    rows.push({ text: "Shell", icon: "", hasChildren: true });
    rows.push({ text: "Session", icon: "", hasChildren: true });
    return rows;
  }
  readonly property int homeAt: sample.rootRows.findIndex((r) => r.id === "home")

  // Home's card: the places over the listing (Places in Home), the dotfiles
  // among it (Hidden files in Home)
  readonly property var homeRows: {
    const rows = [];
    if (Oracle.menuHomePlaces) {
      rows.push({ text: "Documents", icon: "" });
      rows.push({ text: "Downloads", icon: "" });
      rows.push({ text: "Pictures", icon: "" });
      rows.push({ isSeparator: true, enabled: false });
    }
    if (Oracle.menuShowHidden) {
      rows.push({ text: ".config", icon: "", hasChildren: true });
      rows.push({ text: ".local", icon: "", hasChildren: true });
    }
    rows.push({ text: "Desktop", icon: "", hasChildren: true });
    rows.push({ text: "Music", icon: "", hasChildren: true });
    rows.push({ text: "Projects", icon: "", hasChildren: true });
    rows.push({ text: "Videos", icon: "", hasChildren: true });
    return rows;
  }

  // each card as wide as its longest row, measured as CardMenu.fit does
  FontMetrics {
    id: rowMetrics
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(16)
  }
  function fitW(rows) {
    rowMetrics.height;   // again once the face resolves
    let most = 0;
    for (const r of rows) {
      if (!r || r.isSeparator) continue;
      let w = rowMetrics.advanceWidth(String(r.text || "")) + 12 + 10;
      if (r.icon) w += 16 + Zenon.menuIconGap;
      if (r.hasChildren) w += 16 + 8;
      most = Math.max(most, w);
    }
    return Math.max(Zenon.menuMinWidth, Math.ceil(most + Zenon.menuCardPad * 2 + 2 + Zenon.menuFitSlack));
  }
  readonly property real rootW: sample.fitW(sample.rootRows)
  readonly property real homeW: sample.fitW(sample.homeRows)

  function rowH(m) { return m && m.isSeparator ? Zenon.menuSepHeight : Zenon.menuRowHeight; }
  function cardH(rows) {
    let h = 2;
    for (const r of rows) h += sample.rowH(r);
    return h;
  }
  function rowY(rows, i) {
    let y = 1;
    for (let k = 0; k < i && k < rows.length; ++k) y += sample.rowH(rows[k]);
    return y;
  }

  Text {
    id: caption
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: "The desktop's right-click menu at its real width and row height."
    color: sample.dimColor
    font.family: sample.face
    font.pixelSize: Zenon.px(12)
  }

  Item {
    id: stage
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: caption.top
    anchors.topMargin: 16
    anchors.bottomMargin: 10
    clip: true

    // the two cards side by side, centered as a pair
    readonly property real pairW: sample.rootW + (sample.homeAt >= 0 ? sample.homeW : 0)
    readonly property real cardsX: Math.max(24, (stage.width - stage.pairW) / 2)

    // where the click was: the root card opens at the pointer's tip
    Text {
      x: stage.cardsX - 7
      y: -5
      z: 3
      textFormat: Text.PlainText
      text: "\u{F01BF}"
      color: sample.fgColor
      font.family: Zenon.glyphFace
      font.pixelSize: Zenon.px(18)
      style: Text.Outline
      styleColor: Zenon.shade(0.6)
    }

    CardBody {
      id: rootCard
      x: stage.cardsX - rootCard.pad
      y: -rootCard.pad
      width: sample.rootW + rootCard.pad * 2
      height: Math.min(sample.cardH(sample.rootRows), stage.height) + rootCard.pad * 2
      model: sample.rootRows
      activeIndex: sample.hoverAt >= 0 ? sample.hoverAt : sample.homeAt
      onHovered: (i) => sample.hoverAt = i
    }

    CardBody {
      id: home
      visible: sample.homeAt >= 0
      hinged: true
      onRight: true
      pad: 36
      x: stage.cardsX + sample.rootW - home.pad
      y: sample.rowY(sample.rootRows, sample.homeAt) - 1 - home.pad
      width: sample.homeW + home.pad * 2
      height: Math.max(0, Math.min(sample.cardH(sample.homeRows),
                                   stage.height - (home.y + home.pad))) + home.pad * 2
      model: sample.homeRows
    }
  }
}
