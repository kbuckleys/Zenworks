// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE DROP SHELF (2026-11-04) — somewhere to put a thing down on the way
// from one app to another. Drag files, words or a picture to the screen's
// edge (Oracle's Drop shelf, left or right): the shelf slides out under
// the pointer and holds what is let go on it. Drag a held thing back out
// into any app; × takes it off. Bookkeeping in shelf.js.
//
// WHAT IS HELD, AND WHERE (user, 2026-11-04):
//   a file or directory   by reference: never moved, never copied. One
//                         moved or deleted since is dropped from the shelf
//                         the next time it opens.
//   words, a link         written to $XDG_RUNTIME_DIR/zenworks/shelf
//   a web picture         fetched there (delphi's MediaDrop, as a helper)
//   picture data          written there (a screenshot tool's drag)
// The list is kept there too, so a shell restart keeps the shelf; the
// runtime directory goes at logout, and the shelf with it. Not across
// logins: a reference would point at whatever is at that path by then, and
// the shelf is for the trip between two apps, not a place to keep things.
//
// WHY THE EDGE, AND WHAT WAYLAND ALLOWS. A client hears of a drag only when
// the pointer carrying it enters one of its surfaces; nobody is told a drag
// has begun. So the shelf keeps a 1 px strip on its edge (the middle 40%:
// clicks there go to it, not the window under it), and a DRAG entering the
// strip brings the shelf out; a plain pointer does not. What it holds shows
// as a tab on that edge: the pointer on it brings the shelf out too, as do
// Cynosure's "Show the shelf" and `qs ipc call Shelf toggle`.
// Dropping in takes text/uri-list, text/plain and image/* data. Dragging
// out offers text/uri-list with text/plain beside it (paths, or a text
// item's words) — the recipe Cynosure's rows use (DragCard picture, mask
// off while dragging). An app that only takes its own internal drags, or
// only image data, cannot take a file from here; nothing is faked for it.
//
// Loaded by shell.qml through a Loader, which binds `on` and `edge` to
// Oracle (morpheus does not import oracle).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."
import "shelf.js" as S
import "icons.js" as Icons
// base64Of: picture data handed to MediaDrop as delphi's own drop does
import "../delphi/delphi.js" as D
// qualified: the drag card, as Cynosure's rows carry it
import "../terminus" as Term

Item {
  id: shelf

  property bool on: true
  property string edge: "right"
  readonly property bool onLeft: shelf.edge === "left"

  property var items: []
  property int nextId: 1
  readonly property string dir: Paths.runtimeDir() + "/zenworks/shelf"

  // out, and on which screen; `pinned` when asked for (Cynosure, ipc) rather
  // than reached by the pointer: it waits for the pointer to come and go
  property bool shown: false
  property var screen: null
  property bool pinned: false
  // a drag out of the shelf is under way: it stays out, and lets the
  // pointer through to what is under it
  property bool dragging: false
  property bool hovered: false
  property bool dragOver: false
  // the pointer on the edge it came out of: still on the shelf. Without
  // it, a pointer resting on the tab opened the shelf, the tab hid, the
  // shelf closed for want of a pointer and the tab came back under it —
  // the slide replayed every few seconds (user, 2026-11-04)
  property bool edgeHovered: false
  onEdgeHoveredChanged: shelf.settle()

  function open(scr, byPointer) {
    if (!shelf.on) return;
    shelf.screen = scr || Quickshell.screens[0] || null;
    shelf.pinned = !byPointer;
    if (!shelf.shown) { shelf.shown = true; shelf.recheck(); }
    hide.stop();
    // brought out and never reached: a drag that turned back at the edge
    unvisited.restart();
  }
  function close() { shelf.shown = false; shelf.pinned = false; }
  function settle() {
    if (shelf.hovered || shelf.edgeHovered || shelf.dragOver || shelf.dragging) { hide.stop(); unvisited.stop(); shelf.pinned = false; return; }
    if (!shelf.pinned) hide.restart();
  }
  onHoveredChanged: shelf.settle()
  onDragOverChanged: shelf.settle()
  onDraggingChanged: {
    if (!shelf.dragging && shelf.later !== null) { shelf.items = shelf.later; shelf.later = null; }
    shelf.settle();
  }
  onOnChanged: if (!shelf.on) shelf.close()

  Timer { id: hide; interval: 900; onTriggered: shelf.close() }
  // out and never reached (longer when asked for than when a drag found the edge)
  Timer { id: unvisited; interval: shelf.pinned ? 6000 : 2500; onTriggered: if (!shelf.hovered && !shelf.edgeHovered && !shelf.dragOver && !shelf.dragging) shelf.close() }

  // ── the list, kept in the runtime directory ───────────────────────────
  // Through AtomicWriter (audit 2026-11-04): the list went as one `printf`
  // argument, and words are in it — past 128 KiB (one argv string's limit)
  // nothing was written at all.
  //
  // HELD BACK WHILE A ROW IS DRAGGED OUT: a new list rebuilds every row, and
  // the row a drag started from went with it — its dragFinished never came,
  // `dragging` stayed true and the shelf neither closed nor took the pointer
  // again. A fetch landing mid-drag did it. The change waits in `later` and
  // lands when the drag ends; everything reads the list through current().
  property var later: null
  function current() { return shelf.later !== null ? shelf.later : shelf.items; }
  function keep(list) {
    if (shelf.dragging) shelf.later = list;
    else shelf.items = list;
    writer.write(shelf.dir + "/shelf.json", JSON.stringify({ items: list }));
  }
  AtomicWriter { id: writer; tag: "shelf-write" }

  FileView {
    id: stored
    path: shelf.dir + "/shelf.json"
    printErrors: false
    onLoaded: {
      const list = S.parse(stored.text());
      shelf.items = list;
      shelf.nextId = list.reduce((m, it) => Math.max(m, it.id + 1), 1);
    }
  }

  function add(more) {
    if (!more.length) return;
    shelf.nextId = more.reduce((m, it) => Math.max(m, it.id + 1), shelf.nextId);
    shelf.keep(shelf.current().concat(more));
  }
  function remove(id) {
    const it = shelf.current().find((x) => x.id === id);
    if (!it) return;
    if (it.owned && S.ownedPath(it.path, shelf.dir)) Quickshell.execDetached(["rm", "-f", "--", it.path]);
    shelf.keep(shelf.current().filter((x) => x.id !== id));
  }
  function clear() {
    const gone = shelf.current().filter((it) => it.owned && S.ownedPath(it.path, shelf.dir)).map((it) => it.path);
    if (gone.length) Quickshell.execDetached(["rm", "-f", "--"].concat(gone));
    shelf.keep([]);
  }

  // what is no longer there: a file held by reference moved or deleted, or
  // one of the shelf's own swept from the runtime directory (its row would
  // carry a file that is not there)
  function recheck() {
    const paths = shelf.current().map((it) => it.path);
    if (!paths.length || checker.running) return;
    checker.command = ["sh", "-c", 'for p; do [ -e "$p" ] || printf "%s\\0" "$p"; done', "sh"].concat(paths);
    checker.running = true;
  }
  Process {
    id: checker
    stdout: StdioCollector {
      onStreamFinished: {
        const gone = this.text.split("\0").filter((p) => p !== "");
        if (gone.length) shelf.keep(shelf.current().filter((it) => gone.indexOf(it.path) < 0));
      }
    }
  }

  // ── a drop ────────────────────────────────────────────────────────────
  readonly property var imageTypes: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/avif", "image/bmp"]
  function imageType(d) {
    const fs = d.formats || [];
    for (const t of shelf.imageTypes) if (fs.indexOf(t) >= 0) return t;
    return "";
  }
  function dropped(d) {
    const kind = shelf.imageType(d);
    const got = S.sorted(d.hasUrls ? d.urls : [], d.hasText ? d.text : "");
    d.acceptProposedAction();
    if (got.files.length) shelf.addFiles(got.files);
    // the picture the drag carries as data, if any, written out once
    const buf = kind !== "" ? d.getDataAsArrayBuffer(kind) : null;
    let bytes = !!(buf && buf.byteLength > 0);
    const keepBytes = () => {
      bytes = false;
      if (fetchHelp.item) fetchHelp.item.write(D.base64Of(buf), kind.split("/")[1].replace("jpeg", "jpg"), Qt.point(0, 0));
    };
    for (const u of got.web) {
      // a picture's address is fetched; an address with no picture's
      // extension beside picture data is that picture's page or link, so
      // the data is kept rather than fetching a page that is not a picture
      // (it ended in "not a picture" and nothing held: audit 2026-11-04);
      // any other address is held as words
      if (/\.(png|jpe?g|gif|webp|avif|bmp|svg)([?#].*)?$/i.test(u) && fetchHelp.item) fetchHelp.item.fetch(u, Qt.point(0, 0));
      else if (bytes) keepBytes();
      else if (kind !== "" && fetchHelp.item) fetchHelp.item.fetch(u, Qt.point(0, 0));
      else shelf.addText(u);
    }
    if (got.files.length || got.web.length) return;
    if (bytes) { keepBytes(); return; }
    if (got.words.trim() !== "") shelf.addText(got.words);
  }

  // files: which are directories, and that they are there at all
  function addFiles(paths) {
    const p = statter.createObject(shelf, { paths: paths });
    p.running = true;
  }
  Component {
    id: statter
    Process {
      id: st
      property var paths: []
      command: ["sh", "-c", 'for p; do if [ -d "$p" ]; then printf "d%s\\0" "$p"; elif [ -e "$p" ]; then printf "f%s\\0" "$p"; fi; done', "sh"].concat(st.paths)
      stdout: StdioCollector {
        onStreamFinished: {
          const dirs = {}, there = [];
          for (const l of this.text.split("\0")) {
            if (l.length < 2) continue;
            there.push(l.slice(1));
            if (l[0] === "d") dirs[l.slice(1)] = true;
          }
          shelf.add(S.filesIn(shelf.current(), there, dirs, shelf.nextId));
        }
      }
      onExited: st.destroy()
    }
  }

  // words: a file of their own in the runtime directory, so a drag of
  // several carries them as one. Through stdin (AtomicWriter): as a `printf`
  // argument, words past 128 KiB never started and were lost without a word.
  // The same words again are held once, as a file is
  function addText(t) {
    const words = String(t);
    if (shelf.current().some((it) => it.kind === "text" && it.text === words)) return;
    const item = { id: shelf.nextId++, kind: "text", path: "", name: S.textName(words), text: words, owned: true };
    item.path = shelf.dir + "/text-" + item.id + ".txt";
    writer.write(item.path, words, (ok) => {
      if (ok) shelf.add([item]);
      else shelf.failed("The words could not be kept");
    });
  }
  function failed(why) {
    Quickshell.execDetached(["notify-send", "-a", "zenworks", "--", "Not put on the shelf", why]);
  }

  // delphi's MediaDrop, by URL, as a helper only (plato's way): its fetch
  // and write, into the shelf's directory; it takes no drops of its own
  Loader {
    id: fetchHelp
    source: Qt.resolvedUrl("../delphi/MediaDrop.qml")
    onLoaded: {
      item.enabled = false;
      item.dir = Qt.binding(() => shelf.dir);
      item.media.connect((paths) => {
        const more = S.filesIn(shelf.current(), paths, {}, shelf.nextId);
        for (const it of more) it.owned = true;
        shelf.add(more);
      });
      item.failed.connect((why) => shelf.failed(why));
    }
  }

  IpcHandler {
    target: "Shelf"
    function toggle(): string {
      if (shelf.shown) shelf.close(); else shelf.open(null, false);
      return shelf.shown ? "open" : "closed";
    }
    function open(): string { shelf.open(null, false); return shelf.shown ? "open" : "closed"; }
    function hide(): string { shelf.close(); return "closed"; }
  }

  // ── the edge: a strip for a drag to find, and the tab of what is held ──
  Variants {
    model: shelf.on ? Quickshell.screens : []
    PanelWindow {
      id: edgeWin
      required property var modelData
      screen: modelData
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "zenworks-shelf-edge"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      anchors.left: shelf.onLeft
      anchors.right: !shelf.onLeft
      implicitWidth: grip.width + 6
      implicitHeight: Math.round((edgeWin.screen ? edgeWin.screen.height : 1080) * 0.4)
      // the strip and the tab, nothing between: the rest goes to the window
      // under it. Rectangles, not items: a Region with no geometry of its
      // own is the WHOLE surface (clio/ClioBoard's lesson)
      mask: Region {
        x: strip.x
        y: 0
        width: 1
        height: edgeWin.height
        regions: [tabRegion]
      }
      Region {
        id: tabRegion
        x: tabZone.x
        y: tabZone.y
        width: tabZone.width
        height: tabZone.height
      }
      // the grip's area, the pointer resting there keeps the shelf out
      // (shelf.edgeHovered) and brings it out in the first place
      Item {
        id: tabZone
        width: shelf.items.length === 0 ? 0 : grip.width
        height: shelf.items.length === 0 ? 0 : grip.height
        x: grip.x
        y: grip.y
        HoverHandler {
          onHoveredChanged: {
            shelf.edgeHovered = hovered;
            if (hovered) shelf.open(edgeWin.screen, true);
          }
        }
      }

      Item {
        id: strip
        width: 1
        height: parent.height
        x: shelf.onLeft ? 0 : parent.width - 1
      }
      // a drop let go right on the edge (the strip or the tab) is taken
      // too: the shelf comes out a tab's width further in, and a drag
      // released at the edge was lost (audit 2026-11-04). Not its own
      // drag carried back, which would hold its words twice
      DropArea {
        anchors.fill: parent
        onEntered: shelf.open(edgeWin.screen, true)
        onDropped: (d) => { if (!shelf.dragging) shelf.dropped(d); }
      }

      Term.DragCard { id: edgeCard }

      // THE GRIP (user, 2026-11-04): the tab on the edge while something is
      // held, and it stays when the shelf comes out beside it. Dragging it
      // carries the whole shelf; its × takes everything off. The shelf's own
      // frosted ground (EdgeTab's solid strip read as a hollow in the edge),
      // with room around what is in it.
      Rectangle {
        id: grip
        readonly property bool shown: shelf.items.length > 0
        width: 32
        height: gripCol.implicitHeight + 24
        x: shelf.onLeft ? 0 : parent.width - width
        anchors.verticalCenter: parent.verticalCenter
        opacity: grip.shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
        color: allDrag.active ? Zenon.pressFill : Zenon.layerBg
        border.width: 1
        border.color: Zenon.border
        // rounded on the side that faces in, flush on the screen's edge
        radius: Zenon.radiusCard
        topLeftRadius: shelf.onLeft ? 0 : Zenon.radiusCard
        bottomLeftRadius: shelf.onLeft ? 0 : Zenon.radiusCard
        topRightRadius: shelf.onLeft ? Zenon.radiusCard : 0
        bottomRightRadius: shelf.onLeft ? Zenon.radiusCard : 0
        // no line along the screen's edge
        Rectangle {
          color: grip.color
          x: shelf.onLeft ? 0 : parent.width - 1
          y: 1
          width: 1
          height: parent.height - 2
        }
        Column {
          id: gripCol
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: shelf.onLeft ? -1 : 1
          spacing: 8
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uF01C"
            textFormat: Text.PlainText
            color: Zenon.accent
            font.family: Zenon.face
            font.pixelSize: Zenon.px(18)
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String(shelf.items.length)
            textFormat: Text.PlainText
            color: Zenon.ink
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(12)
          }
          // everything off the shelf, the × alone with no disc behind it
          ClearChip {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Zenon.px(13)
            color: "transparent"
            onClicked: shelf.clear()
          }
        }
        Drag.active: false
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.onDragFinished: { grip.Drag.active = false; shelf.dragging = false; }
        DragHandler {
          id: allDrag
          target: null
          enabled: grip.shown
          onActiveChanged: if (active)
            shelf.offer(edgeCard, grip, shelf.items, shelf.items.length === 1 ? shelf.items[0].name : shelf.items.length + " items", "\uF01C", "")
        }
      }
    }
  }

  // ── the shelf: the container alone, out beside the grip ───────────────
  PanelWindow {
    id: win
    // mapped until the collapse is over: a binding on the animations' running
    // let it unmap for a moment as `shown` fell, and map again
    visible: shelf.on && card.held
    screen: shelf.screen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "zenworks-shelf"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.left: shelf.onLeft
    anchors.right: !shelf.onLeft
    // clear of the grip on the edge (32 and a gap), with room for the shadow
    readonly property int beside: 32 + 6
    implicitWidth: card.width + win.beside + Zenon.menuShadowPad
    implicitHeight: card.height + Zenon.menuShadowPad * 2
    // nothing while dragging out: the pointer goes through to the drop
    // target. Explicitly zero, not an empty item (that is the whole surface)
    mask: Region {
      x: card.x
      y: card.y
      width: shelf.dragging ? 0 : card.width
      height: shelf.dragging ? 0 : card.height
    }

    Term.DragCard { id: dragCard }

    LayerShadow { panel: card; fade: card.opacity; scale: card.scale; cornerRadius: Zenon.radiusCard }

    Rectangle {
      id: card
      x: shelf.onLeft ? win.beside : win.width - card.width - win.beside
      y: Zenon.menuShadowPad
      // THE OSD'S POP, FASTER (user, 2026-11-04): over its size and back
      // where it stands (OutBack, howler/HowlerOsd's curve at 180 ms rather
      // than its 280), no slide. Going, no pop at all: it shrinks and fades
      opacity: 0
      scale: 0.72
      readonly property int popMs: 180
      property bool held: false
      ParallelAnimation {
        id: arrive
        NumberAnimation { target: card; property: "scale"; from: 0.72; to: 1; duration: card.popMs
                          easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: Math.round(card.popMs * 0.6); easing.type: Zenon.ease }
      }
      ParallelAnimation {
        id: leave
        NumberAnimation { target: card; property: "scale"; to: 0.72; duration: card.popMs
                          easing.type: Easing.InCubic }
        onFinished: card.held = false
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: card.popMs; easing.type: Easing.InQuart }
      }
      Connections {
        target: shelf
        function onShownChanged() {
          if (shelf.shown) { leave.stop(); card.held = true; arrive.restart(); }
          else { arrive.stop(); leave.restart(); }
        }
      }
      width: Zenon.px(15) * 17
      height: Math.min(Math.max(body.contentHeight, Zenon.px(15) * 4) + 8,
                       // at most 80% of the screen, then it scrolls (elastic, ElasticScroll)
                       (shelf.screen ? shelf.screen.height : 1080) * 0.8)
      // WHAT IS HELD, IN ONE CONTAINER, and the container is the window:
      // no card around it (user, 2026-11-04)
      radius: Zenon.radiusCard
      color: Zenon.layerBg
      border.width: 1
      border.color: Zenon.border
      clip: true

      HoverHandler { onHoveredChanged: shelf.hovered = hovered }
      DropArea {
        anchors.fill: parent
        onEntered: shelf.dragOver = true
        onExited: shelf.dragOver = false
        onDropped: (d) => { shelf.dragOver = false; if (!shelf.dragging) shelf.dropped(d); }
      }

      ListView {
        id: body
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: shelf.items
        delegate: Item {
          id: row
          required property var modelData
          width: body.width
          height: Zenon.px(15) * 3
          Drag.active: false
          Drag.dragType: Drag.Automatic
          Drag.supportedActions: Qt.CopyAction
          Drag.hotSpot.x: 16
          Drag.hotSpot.y: 19
          Drag.onDragFinished: { row.Drag.active = false; shelf.dragging = false; }
          DragHandler {
            target: null
            onActiveChanged: if (active)
              shelf.offer(dragCard, row, [row.modelData], row.modelData.name, pic.glyph,
                          row.modelData.kind === "image" ? Strings.fileUrl(row.modelData.path) : "")
          }

          Item {
            id: pic
            readonly property string glyph: row.modelData.kind === "text" ? "\uF15C"
              : Icons.glyphFor({ name: row.modelData.name, path: row.modelData.path, isDir: row.modelData.kind === "dir" }) || "\uF15B"
            width: Zenon.px(15) * 2.2
            height: width
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Image {
              id: thumb
              anchors.fill: parent
              visible: row.modelData.kind === "image" && thumb.status === Image.Ready
              source: row.modelData.kind === "image" ? Strings.fileUrl(row.modelData.path) : ""
              sourceSize.width: 96
              sourceSize.height: 96
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }
            Text {
              anchors.centerIn: parent
              visible: !thumb.visible
              text: pic.glyph
              textFormat: Text.PlainText
              color: row.modelData.kind === "text" ? Zenon.soft : Zenon.accent
              font.family: Zenon.face
              font.pixelSize: Zenon.px(22)
            }
          }
          Column {
            anchors.left: pic.right
            anchors.leftMargin: 10
            anchors.right: remover.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
              width: parent.width
              text: row.modelData.name
              textFormat: Text.PlainText
              // a file's name keeps its end (the extension); words read from the start
              elide: row.modelData.kind === "text" ? Text.ElideRight : Text.ElideMiddle
              color: Zenon.ink
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(14)
            }
            Text {
              width: parent.width
              text: row.modelData.kind === "text" ? "Text"
                : row.modelData.kind === "dir" ? "Directory"
                : row.modelData.owned ? "Picture" : row.modelData.path.replace(/\/[^\/]*$/, "") || "/"
              textFormat: Text.PlainText
              elide: Text.ElideMiddle
              color: Zenon.soft
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(12)
            }
          }
          ClearChip {
            id: remover
            size: Zenon.px(14)
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            onClicked: shelf.remove(row.modelData.id)
          }
        }
      }
      ElasticScroll { anchors.fill: body; view: body }
      Scrollbar { z: 2; flick: body; anchors.right: body.right; anchors.top: body.top; anchors.bottom: body.bottom }

      EmptyState {
        anchors.centerIn: parent
        visible: shelf.items.length === 0
        text: "Drop files, words or pictures here"
      }
    }
  }

  // a drag out, once its card is drawn
  // (`pic`: the DragCard in the window the drag starts from, so it is drawn
  // there even while the other is hidden)
  function offer(pic, item, list, label, glyph, thumbUrl) {
    shelf.dragging = true;
    pic.label = label;
    pic.glyph = glyph;
    pic.ink = Zenon.accent;
    pic.count = list.length;
    pic.thumb = thumbUrl || "";
    pic.picture((url) => {
      item.Drag.mimeData = S.mimeOf(list);
      item.Drag.imageSource = url;
      item.Drag.active = true;
    });
  }
}
