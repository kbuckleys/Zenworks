// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE BELL'S PANEL — what has already happened. The toasts are the present
// tense and this is the past one, which is why it reads `Howler.history` and
// not the server: a row here may well belong to an application that has since
// exited, and nothing in it can be dismissed because it is already gone.
//
// It opens from the bell in the bar, and it is a morph layer like every other
// panel — see panelX/panelY and contentFade, which are the shared shape of
// one growing out of the pill rather than appearing over it.

import QtQuick
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland
import "../morpheus"
import "../oracle"
import "howler.js" as Wolf

LayerPopup {
  id: popup

  focusable: true

  // Filtering is a view, not a change — nothing is removed from the history
  // by narrowing it, and clearing the filter brings it all back.
  property string appFilter: ""

  readonly property var apps: {
    const seen = ({}); const out = [];
    for (let i = 0; i < Howler.history.length; ++i) {
      const a = String(Howler.history[i].appName || "");
      if (a === "" || seen[a]) continue;
      seen[a] = true; out.push(a);
    }
    return out;
  }

  readonly property var rows: {
    if (popup.appFilter === "") return Howler.history;
    const out = [];
    for (let i = 0; i < Howler.history.length; ++i)
      if (String(Howler.history[i].appName || "") === popup.appFilter)
        out.push(Howler.history[i]);
    return out;
  }
  readonly property int rowH: 64

  // Tall enough for what it holds, then capped — a history of two hundred is
  // a scroll, not a panel the height of the screen. shell.qml asks for this
  // by name to size the morph.
  function calcHeight() {
    const n = Math.max(1, popup.rows.length);
    return Math.min(Oracle.notifMaxHeight + 96,
                    96 + n * popup.rowH + 12);
  }

  HyprlandFocusGrab {
    id: grab
    // the row menu is a layer surface of its own: in the grab, or opening
    // it would read as a click away (as Zeus' profile menu)
    windows: rowMenu.visible ? [ popup, rowMenu ] : [ popup ]
    active: popup.shown
    onCleared: popup.closePopup()
  }

  // ── A ROW'S MENU (2026-11-03) ─────────────────────────────────────────
  // Right click on a row: open it, copy it, dismiss it or all from its app,
  // and mute or block the app (Howler.setSource — Oracle's Muted apps).
  // Built when it opens, not bound: the row it was opened on is what it acts on.
  property bool rowMenuOpen: false
  property point rowMenuAt: Qt.point(0, 0)
  property var rowMenuRow: null
  property var rowMenuRows: []

  function rowMenuFor(r) {
    const src = Howler.sourceOf(r);
    const name = String(r.appName || "") || src;
    const st = Howler.sourceState(src);
    const words = String(r.summary || "") + (r.body ? "\n" + r.body : "");
    const out = [
      { text: "Open", icon: "\u{F03CC}", act: "open" },
      { text: "Copy text", icon: "\u{F018F}", act: "copy", enabled: words.trim() !== "" },
      { isSeparator: true },
      { text: "Dismiss", icon: "\u{F0156}", act: "forget" }
    ];
    if (src === "") return out;
    out.push({ text: "Dismiss all from " + name, icon: "\u{F039A}", act: "forgetAll" });
    out.push({ isSeparator: true });
    out.push(st === "mute"
      ? { text: "Unmute " + name, icon: "\u{F009C}", act: "unmute" }
      : { text: "Mute " + name, icon: "\u{F0A92}", act: "mute" });
    out.push(st === "block"
      ? { text: "Unblock " + name, icon: "\u{F009C}", act: "unblock" }
      : { text: "Block " + name, icon: "\u{F073A}", act: "block" });
    return out;
  }

  // `item` and `pos` (in item's coordinates) are where the click landed
  function openRowMenu(r, item, pos) {
    if (!r || !item) return;
    const o = Zenon.winOrigin(popup, popup.screen);
    const p = item.mapToItem(null, pos.x, pos.y);
    popup.rowMenuRow = r;
    popup.rowMenuRows = popup.rowMenuFor(r);
    popup.rowMenuAt = Qt.point(o.x + p.x, o.y + p.y);
    popup.rowMenuOpen = true;
  }
  function closeRowMenu() { popup.rowMenuOpen = false; }

  function rowMenuChose(i) {
    const m = popup.rowMenuRows[i];
    const r = popup.rowMenuRow;
    popup.closeRowMenu();
    if (!m || !r) return;
    const src = Howler.sourceOf(r);
    switch (m.act) {
      case "open": popup.closePopup(); Howler.openRow(r); break;
      case "copy":
        Strings.copy((String(r.summary || "") + (r.body ? "\n" + r.body : ""))
          .replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
          .replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&").trim());
        break;
      case "forget": Howler.forget(r); break;
      case "forgetAll":
        if (popup.appFilter === String(r.appName || "")) popup.appFilter = "";
        Howler.forgetSource(src);
        break;
      case "mute": Howler.setSource(src, "mute"); break;
      case "block": Howler.setSource(src, "block"); break;
      case "unmute": case "unblock": Howler.setSource(src, ""); break;
    }
  }

  CardMenu {
    id: rowMenu
    screen: popup.screen
    open: popup.rowMenuOpen && popup.shown
    at: popup.rowMenuAt
    model: popup.rowMenuRows
    fit: true
    onChosen: (i) => popup.rowMenuChose(i)
  }

  // The four the bar, the keybind and the terminal all reach for. Each answers
  // with what it did rather than nothing, so `qs ipc call Howler stat` is
  // useful from a script and not only from a menu.
  IpcHandler {
    target: "Howler"

    function toggle(): void { popup.toggle(); }

    function stat(): string {
      const live = Howler.live ? Howler.live.values.length : 0;
      return live + " showing, " + Howler.history.length + " kept, "
        + Howler.unread + " unread";
    }

    function dismiss(): string {
      const live = Howler.live ? Howler.live.values.length : 0;
      Howler.dismissAll();
      return "dismissed " + live;
    }

    function clear(): string {
      const n = Howler.history.length;
      Howler.dismissAll();
      Howler.clearHistory();
      return "cleared " + n;
    }

    // do not disturb, flipped — worth a keybind, since the bell that also
    // flips it is hidden while there is nothing to count and it is off
    function silent(): string {
      Howler.toggleSilent();
      return Howler.silent ? "do not disturb" : "toasts back on";
    }
  }

  function openPopup() {
    popup.shown = true;
    popup.collapsing = false;
    // Opening the panel IS reading it — the bell goes quiet the moment the
    // list is on screen rather than when a row is clicked, because there is
    // nothing here to click through to.
    Howler.markRead();
    // a screenshot deleted since the last look is left out (capturesGone)
    Howler.checkCaptures();
    popup.playOpen();
    Qt.callLater(() => { if (popup.shown) bgRoot.forceActiveFocus(); });
  }

  function closePopup() {
    popup.closeRowMenu();
    popup.collapsing = true;
    popup.playClose();
  }

  function toggle() {
    if (popup.shown) popup.closePopup();
    else popup.openPopup();
  }

  MouseArea {
    anchors.fill: parent
    z: 0
    onClicked: popup.closePopup()
  }

  LayerPanel {
    id: panel
    host: popup
    ground: bgRoot
    width: Zenon.layerWidth(800)
    height: popup.calcHeight()

    ClippingRectangle {
      id: bgRoot
      anchors.fill: parent
      // Transparent while morphing: the pill underneath is already drawing
      // the ground, and two grounds compositing read as a darker card that
      // lightens as it settles.
      color: popup.morphMode ? "transparent" : Zenon.layerBg
      border.color: Zenon.border
      border.width: 1
      radius: Zenon.pillRadius
      focus: true

      // Escape closes, as chronos' does: the layer holds the focus grab, so
      // it has to give the keys back somehow (user, 2026-10-19)
      Keys.onEscapePressed: (event) => {
        event.accepted = true;
        if (popup.rowMenuOpen) popup.closeRowMenu();
        else popup.closePopup();
      }

      // Rows scrolled up past the list's top carry on under the head and the
      // chips, frosted — morpheus/ScrollEdge, as every other list here does.
      // Declared before both so it lies under them.
      ScrollEdge {
        view: list
        x: list.x
        width: list.width
        height: list.y
      }

      // ── the head ────────────────────────────────────────────────────
      Item {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          text: popup.rows.length === 0 ? "Notifications"
              : "Notifications  " + popup.rows.length
          color: Zenon.accent
          font.family: Zenon.face
          font.weight: Font.Bold
          font.pixelSize: Zenon.px(16)
        }

        // ── WHAT THE BAR HOLDS ON THE RIGHT ──────────────────────────
        // A Row rather than two things anchored to the same edge: `clear`
        // comes and goes with the list, and anything anchored beside it
        // would have to know that. A Row skips what is not there and closes
        // the gap itself.
        Row {
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          spacing: 12

          // ── TRACK MUSIC, OR DO NOT ─────────────────────────────────
          // It was a chip in the filter row reading "music tracked" /
          // "music ignored" — a sentence, sitting among the app filters as
          // though it were one of them. It is not a filter: the filters say
          // which of these notifications to show, and this says whether a
          // whole kind of them is ever kept at all. So it belongs on the
          // bar with `clear`, which is the other thing here that changes
          // what the list IS rather than what of it you are looking at.
          //
          // A GLYPH RATHER THAN A SENTENCE, lit when it is on — the same way
          // the bar's own mute reads, and it says it in a quarter the width.
          Rectangle {
            id: musicBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 22
            radius: Zenon.radiusControl
            color: Howler.trackMusic
              ? Qt.rgba(Zenon.accent.r, Zenon.accent.g, Zenon.accent.b, 0.18)
              : (musicPress.pressed ? Zenon.wash(0.08) : "transparent")
            border.width: 1
            border.color: Howler.trackMusic ? Zenon.accent : Zenon.border
            Behavior on color { ColorAnimation { duration: Zenon.fast } }
            Behavior on border.color { ColorAnimation { duration: Zenon.fast } }

            Text {
              anchors.centerIn: parent
              text: "\uF001"
              color: Howler.trackMusic ? Zenon.accent
                : (musicPress.pressed ? Zenon.white : Zenon.keyInk)
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(12)
              Behavior on color { ColorAnimation { duration: Zenon.fast } }
            }

            HoverHandler { id: musicHov }
            TapHandler { id: musicPress; onTapped: Howler.toggleMusicTracking() }
          }

          // ── DO NOT DISTURB ─────────────────────────────────────────
          // The music switch's twin: a glyph, lit while on. It is the same
          // setting the bell's right click flips.
          Rectangle {
            id: silentBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 22
            radius: Zenon.radiusControl
            color: Howler.silent
              ? Qt.rgba(Zenon.accent.r, Zenon.accent.g, Zenon.accent.b, 0.18)
              : (silentPress.pressed ? Zenon.wash(0.08) : "transparent")
            border.width: 1
            border.color: Howler.silent ? Zenon.accent : Zenon.border
            Behavior on color { ColorAnimation { duration: Zenon.fast } }
            Behavior on border.color { ColorAnimation { duration: Zenon.fast } }

            Text {
              anchors.centerIn: parent
              text: "󰂛"
              color: Howler.silent ? Zenon.accent
                : (silentPress.pressed ? Zenon.white : Zenon.keyInk)
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(13)
              Behavior on color { ColorAnimation { duration: Zenon.fast } }
            }

            HoverHandler { id: silentHov }
            TapHandler { id: silentPress; onTapped: Howler.toggleSilent() }
          }

          Text {
            id: clearBtn
            anchors.verticalCenter: parent.verticalCenter
            visible: popup.rows.length > 0
            text: "Clear"
            color: clearPress.pressed ? Zenon.red : Zenon.muted
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(13)
            HoverHandler { id: clearHov }
            TapHandler {
              id: clearPress
              onTapped: { Howler.dismissAll(); Howler.clearHistory(); }
            }
          }
        }

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: 1
          color: Zenon.border
        }
      }

      // Nothing to show is worth saying once, in the middle, rather than
      // leaving an empty card that reads as a panel that failed to load.
      // CENTERED ON THE LIST, not on the card. The head is 44 tall and sits
      // above it, so centering in the whole card pushed this down by half of
      // that — which reads as "nearly centered", the worst kind.
      EmptyState {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: chips.bottom
        anchors.bottom: parent.bottom
        verticalAlignment: Text.AlignVCenter
        visible: popup.rows.length === 0
        text: "Nothing yet"
      }

      // ── THE CHIP ──────────────────────────────────────────────────
      // One shape for both jobs: a switch that is on or off, and a filter
      // that is chosen or not. `on` is the state, `lit` is the press (no hover tints).
      component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool on: false
        readonly property bool lit: chipTap.pressed
        signal picked()

        width: chipText.implicitWidth + 20
        height: 24
        radius: Zenon.radiusControl
        color: chip.on ? Qt.rgba(Zenon.sand.r, Zenon.sand.g, Zenon.sand.b, 0.20)
                       : "transparent"
        border.color: chip.on ? Zenon.sand : Zenon.border
        border.width: 1

        Text {
          textFormat: Text.PlainText
          id: chipText
          anchors.centerIn: parent
          text: chip.label
          color: chip.on ? Zenon.sand : (chip.lit ? Zenon.white : Zenon.keyInk)
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(12)
        }

        TapHandler { id: chipTap; onTapped: chip.picked() }
      }

      Flickable {
        id: chips
        // the wheel or a touchpad moves the chips along (morpheus Elastic)
        ElasticScroll { view: chips; horizontal: true; step: 120 }
        anchors.top: head.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        // COLLAPSED WHEN EMPTY. The music toggle used to be in here, so the
        // row always had something in it; with only app filters left, a
        // history from one application has nothing to put here and a 24px
        // strip of nothing above the list is not a filter bar.
        anchors.topMargin: chips.height > 0 ? 10 : 0
        height: chipRow.width > 0 ? 24 : 0
        visible: chips.height > 0
        contentWidth: chipRow.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
          id: chipRow
          spacing: 8

          Chip {
            visible: popup.appFilter !== ""
            label: "All"
            on: false
            onPicked: popup.appFilter = ""
          }

          Repeater {
            model: popup.apps
            delegate: Chip {
              required property var modelData
              // a muted app's chip wears the bell-off mark its rows do
              // (asked by Howler.sourceOf, the key the door and the rows use)
              label: modelData + (Howler.sourceState(Howler.sourceOf({ appName: modelData })) === "mute"
                ? "  \u{F0A92}" : "")
              on: popup.appFilter === modelData
              onPicked: popup.appFilter =
                (popup.appFilter === modelData ? "" : modelData)
            }
          }
        }
      }

      // the suite's scrollbar, as folio's and ideo's: a sibling, not a
      // child — inside the view it would scroll away with the rows — and
      // it hides itself when every row fits
      Scrollbar {
        z: 2
        flick: list
        anchors.right: list.right
        anchors.top: list.top
        anchors.bottom: list.bottom
      }

      ListView {
        id: list
        // Finder's rubber band and the smooth wheel notch, one rule for
        // the whole shell — see morpheus/Elastic.qml. Inside the view
        // rather than over it: it pins itself to the viewport.
        ElasticScroll { view: list }
        anchors.top: chips.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10
        anchors.bottomMargin: 6
        clip: true
        model: popup.rows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 0

        delegate: Item {
          id: row
          required property var modelData
          required property int index
          width: list.width
          height: popup.rowH

          // A CALENDAR REMINDER KEEPS ITS TOAST'S LOOK (user, 2026-10-28):
          // washed in the event's hue, a band of it down the edge, and its
          // date tile where the icon would be
          // A MUTED APP'S ROW (2026-11-03): faded, and the bell-off mark
          // before its app name — it came in quietly, and still would
          readonly property bool muted: Howler.sourceState(Howler.sourceOf(row.modelData)) === "mute"
          readonly property real mutedFade: row.muted ? 0.5 : 1
          readonly property bool event: !!row.modelData.eventHue
          readonly property color eventInk: Howler.eventInk(row.modelData.eventHue)
          readonly property var eventDay: Howler.eventDayOf(row.modelData.eventDay)
          ClippingRectangle {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            visible: row.event
            radius: Howler.radius
            color: Zenon.alpha(row.eventInk, Zenon.light ? 0.12 : 0.16)
            Rectangle { width: 4; height: parent.height; color: row.eventInk }
          }
          Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            radius: Howler.radius
            color: rowHov.hovered ? Zenon.menuHi : "transparent"
          }
          HoverHandler { id: rowHov }

          Rectangle {
            id: rowTile
            visible: row.event
            opacity: row.mutedFade
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: Zenon.rad(2)
            color: Zenon.alpha(row.eventInk, 0.22)
            border.width: 1
            border.color: Zenon.alpha(row.eventInk, 0.6)
            Column {
              anchors.centerIn: parent
              spacing: -2
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale().dayName(row.eventDay.getDay(), Locale.ShortFormat).toUpperCase()
                color: row.eventInk
                font.family: Zenon.face
                font.weight: Font.Bold
                font.pixelSize: Zenon.px(10)
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: row.eventDay.getDate()
                color: Zenon.ink
                font.family: Zenon.face
                font.weight: Font.Bold
                font.pixelSize: Zenon.px(20)
              }
            }
          }

          // The row's own icon, at the size oracle asks for — the image the
          // application sent if it survived being written down, and its
          // themed icon if it did not. See howler.js for which is which.
          // A row with nothing to show takes no room for it (user,
          // 2026-10-29): no empty box, the words start where it would have.
          // Something to show is a picture that loaded, or the question mark
          // for one that was named and cannot be had — as the toast's hasIcon.
          ClippingRectangle {
            id: shot
            readonly property bool missing: (!!row.modelData.appIcon || !!row.modelData.rawImage)
              && shotImg.pictures.length === 0 && !shotImg.waiting
              && (shotImg.source.toString() === "" || shotImg.status === Image.Error)
            readonly property bool hasPicture: Howler.iconsEnabled && !row.event
              && (shot.missing
                  || (shotImg.source.toString() !== "" && shotImg.status !== Image.Error))
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: shot.hasPicture ? 40 : 0
            height: 40
            visible: shot.hasPicture
            opacity: row.mutedFade
            radius: Howler.iconRadius
            color: "transparent"

            Image {
              id: shotImg
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              cache: true
              asynchronous: true
              sourceSize.width: 80
              sourceSize.height: 80
              // A capture is its own picture, while the file is still there —
              // one found gone is never tried (Howler.capturesGone); each that
              // will not load all the same gives way to the next, and the last
              // to the row's icon below. Nothing is tried before the check.
              readonly property var pictures: Wolf.capturePictures(row.modelData, Howler.capturesGone)
              readonly property bool waiting: !Howler.capturesChecked
                && Wolf.capturePaths(row.modelData).length > 0
              property int tried: 0
              onPicturesChanged: tried = 0
              onStatusChanged: if (status === Image.Error
                                   && tried < pictures.length
                                   && source.toString() === pictures[tried]) tried++
              source: {
                const r = row.modelData;
                if (shotImg.waiting) return "";
                if (shotImg.tried < shotImg.pictures.length) return shotImg.pictures[shotImg.tried];
                // (rows kept from before carry image://icon/ addresses; an
                // http cover goes through NowPlaying's curl cache, as the
                // toast's does — never Qt's HTTP/2, audit 2026-10-28b)
                const im = NowPlaying.art(Howler.imageSource(r.image));
                if (im !== "") return im;
                // a file, a file:// address, or a themed name the theme has
                const ic = Howler.iconSource(r.appIcon);
                if (ic !== "") return ic;
                return "";
              }
            }
            // named and not to be had: the question mark (Howler.missingGlyph)
            Text {
              anchors.centerIn: parent
              visible: shot.missing
              text: Howler.missingGlyph
              color: Zenon.accentMuted
              font.family: Zenon.glyphFace
              font.pixelSize: Zenon.px(24)
            }
          }

          Text {
            textFormat: Text.PlainText
            id: appLine
            opacity: row.mutedFade
            anchors.left: row.event ? rowTile.right : shot.right
            anchors.leftMargin: row.event ? 16 : shot.hasPicture ? 14 : 0
            anchors.right: stamp.left
            anchors.rightMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 12
            elide: Text.ElideRight
            text: row.modelData.summary !== "" ? row.modelData.summary
                : row.modelData.appName
            color: row.modelData.urgency === 2 && !row.event ? Zenon.red : Zenon.white
            font.family: Zenon.face
            font.weight: Font.Bold
            font.pixelSize: Zenon.px(14)
          }

          Text {
            anchors.left: appLine.left
            anchors.right: appLine.right
            anchors.top: appLine.bottom
            anchors.topMargin: 2
            elide: Text.ElideRight
            visible: text !== ""
            opacity: row.mutedFade
            text: Wolf.safeMarkup(row.modelData.body)
            textFormat: Howler.markup ? Text.StyledText : Text.PlainText
            color: row.event ? row.eventInk : Zenon.muted
            font.family: Zenon.face
            font.weight: Font.Bold
            font.pixelSize: Zenon.px(13)
          }

          // Where it came from and when, in the one place the eye is not
          // reading — the right edge, dimmest thing on the row.
          Text {
            id: stamp
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 12
            text: Qt.formatDateTime(new Date(row.modelData.time || 0), "HH:mm")
            color: Zenon.muted
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(12)
          }

          Text {
            textFormat: Text.PlainText
            id: appTag
            anchors.right: stamp.right
            anchors.top: stamp.bottom
            anchors.topMargin: 2
            text: row.modelData.appName || ""
            color: Zenon.dimInk
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(11)
          }

          Text {
            anchors.right: appTag.left
            anchors.rightMargin: appTag.text !== "" ? 6 : 0
            anchors.verticalCenter: appTag.verticalCenter
            visible: row.muted
            text: "\u{F0A92}"
            color: Zenon.accentMuted
            font.family: Zenon.glyphFace
            font.pixelSize: Zenon.px(13)
          }

          // As a toast answers (user, 2026-10-18): left opens where it came
          // from — Howler.openRow — and closes the panel on the flare's
          // tail. Right opens the row's menu (2026-11-03), where Dismiss
          // is the "I have seen it" a right click used to be.
          TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
              if (rowOpen.running || popup.collapsing) return;
              rowFlare.fire();
              rowOpen.start();
            }
          }
          TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (point) => popup.openRowMenu(row.modelData, row, point.position)
          }
          Timer {
            id: rowOpen
            interval: rowFlare.rise
            onTriggered: {
              const r = row.modelData;
              popup.closePopup();
              Howler.openRow(r);
            }
          }
          OpenFlare {
            id: rowFlare
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            radius: Howler.radius
            wash: false
            z: 10
          }
        }
      }
    }
  }

  // a click anywhere on the panel that is not the menu puts the menu away
  // without reaching what was under it (as Zeus')
  MouseArea {
    anchors.fill: parent
    z: 10
    visible: popup.rowMenuOpen
    acceptedButtons: Qt.AllButtons
    onPressed: popup.closeRowMenu()
    onWheel: (wheel) => popup.closeRowMenu()
  }
}
