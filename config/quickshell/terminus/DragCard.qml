// What the pointer carries while something is dragged out of the suite: a
// small card with the thing's glyph (or a thumbnail of it), its name, and a
// count when there is more than one. One card for terminus, artemis, folio
// and picasso, so a drag looks the same wherever it starts.
//
// A platform drag has no picture unless one is given to it: Drag.imageSource
// takes a URL, and grabToImage renders a live item into one. So the card is
// drawn for real — off to one side and fully transparent, but in the scene,
// because grabToImage renders an item's subtree and an item that is
// `visible: false` is not in the graph to render.
//
// Use: fill the properties in, then picture(then) — and start the drag from
// inside `then`, with the url it is handed. Drag.imageSource is read when
// Drag.active turns true and grabToImage answers a frame later, so the other
// way round every drag carries the previous one's picture.
//
// SEVERAL AT ONCE GATHER UNDER THE POINTER, as macOS does (user, 2026-11-07).
// The card itself is a pile when count is above 1, wherever it is used, and
// flock() sends a picture of each thing on screen flying from where it lies
// to the pointer. Call it just before picture():
//
//     card.flock((it) => it.objectName === "row" && chosen[it.path], at)
//
// `test` is asked of every visible item in the window, `at` is the pointer in
// window coordinates. On Wayland the drag's picture is one still image the
// compositor carries, so the flight happens inside the window, and a drag that
// is cancelled drops where it is, with no flight home: the shell does not know
// where the pointer went once it left.
import QtQuick
import QtQuick.Window
import Quickshell.Widgets
import "../morpheus"

Item {
  id: card

  property string label: ""
  property string glyph: ""
  property color ink: Zenon.white
  // above 1, rides along as a badge — "1" beside a filename is noise
  property int count: 1
  // a picture of the thing, in the glyph's place, when there is one
  property string thumb: ""

  // Held so the grab result is not collected: Drag.imageSource points at a
  // url that lives exactly as long as this object does.
  property var grab: null

  function picture(then) {
    // A failed grab is not a reason to refuse the drag; it just goes without
    // a picture.
    if (!card.grabToImage((res) => { card.grab = res; then(res.url); }))
      then("");
  }

  // ── the flight ──
  // the most that FLY, top of the screen first: a thousand marked rows would
  // only cost the drag's start. Every one of them dims, or a selection reads
  // as two different selections (user, 2026-11-07).
  readonly property int flockMax: 12
  function flockItems(test) {
    const root = card.Window.contentItem;
    if (!root) return [];
    const out = [];
    const walk = (it, l, t, r, b) => {
      if (!it.visible || it.opacity <= 0 || it === card) return;
      const p = it.mapToItem(root, 0, 0);
      if (it !== root && it.clip) {
        l = Math.max(l, p.x); t = Math.max(t, p.y);
        r = Math.min(r, p.x + it.width); b = Math.min(b, p.y + it.height);
        if (l >= r || t >= b) return;
      }
      if (it !== root && test(it)) {
        // scrolled out of the view it lies in: not on screen to fly from
        if (it.width > 0 && it.height > 0 && p.x < r && p.y < b && p.x + it.width > l && p.y + it.height > t)
          out.push({ item: it, x: p.x, y: p.y });
        return;
      }
      for (const c of it.children) walk(c, l, t, r, b);
    };
    walk(root, 0, 0, root.width, root.height);
    // the delegates' own order is whatever the view recycled them into
    return out.sort((a, b) => a.y - b.y || a.x - b.x);
  }
  // what a drag has out: the originals' dims, and where to fly home to
  property var out: []
  // `face(item)` says { glyph, ink, label } when an item should travel as a
  // card rather than as a picture of itself: a list row is a whole column wide,
  // and what leaves it is the thing's mark and name, not the slab (macOS).
  function flock(test, at, face) {
    const root = card.Window.contentItem;
    card.landed(Qt.CopyAction);
    if (!root || !at) return;
    const home = [];
    card.flockItems(test).forEach((f, i) => {
      const it = f.item;
      const look = face ? face(it) : null;
      const to = { x: at.x - 16, y: at.y - card.faceH / 2 };
      const one = { x: f.x, y: f.y, w: it.width, h: it.height, look: look, url: "", picture: null, at: to };
      home.push(one);
      one.dim = dimmer.createObject(card, { target: it, key: card.keyOf(it) });
      if (i >= card.flockMax) return;
      if (look) { one.y = f.y + (it.height - card.faceH) / 2; card.launch(root, one, false, i); }
      else it.grabToImage((res) => {
        one.picture = res; one.url = res.url;
        card.launch(root, one, false, i);
      });
    });
    card.out = home;
  }
  // The drag ended. Taken, the originals simply come back; refused, each
  // flies home first, the way it left.
  function landed(action) {
    const root = card.Window.contentItem;
    const home = card.out;
    card.out = [];
    home.forEach((one, i) => {
      if (action === Qt.IgnoreAction && root && i < card.flockMax) card.launch(root, one, true, i);
      else if (one.dim) one.dim.destroy();
    });
  }
  function launch(root, one, back, i) {
    flight.createObject(root, { one: one, back: back, lag: i * 12 });
  }
  // what a delegate shows: a view that scrolls under the drag hands the
  // same delegate another row, and that row was dimmed in its place
  // (audit 2026-11-07) — the dim holds only while the row is the one taken
  function keyOf(it) {
    if (!it) return null;
    // the row's index: a var-array model's modelData is a fresh copy on
    // every read, so it never compares equal to itself
    return it.index !== undefined ? it.index : null;
  }
  Component {
    id: dimmer
    Binding {
      id: dimBind
      property var key: null
      property: "opacity"
      value: 0.35
      when: dimBind.target !== null && (dimBind.key === null || card.keyOf(dimBind.target) === dimBind.key)
      restoreMode: Binding.RestoreBindingOrValue
    }
  }
  Component {
    id: flight
    Item {
      id: flown
      property var one: null
      property bool back: false
      property int lag: 0
      readonly property int span: Zenon.normal * 2
      // an item travels at its own size and ends at the card's height
      readonly property real endScale: flown.one.look ? 1 : Math.min(1, card.faceH / flown.one.h)
      z: 100000
      x: flown.back ? flown.one.at.x : flown.one.x
      y: flown.back ? flown.one.at.y : flown.one.y
      width: flown.one.look ? flownCard.width : flown.one.w
      height: flown.one.look ? card.faceH : flown.one.h
      scale: flown.back ? flown.endScale : 1
      transformOrigin: Item.TopLeft
      Image {
        visible: !flown.one.look
        anchors.fill: parent
        source: flown.one.url
      }
      Rectangle {
        id: flownCard
        visible: !!flown.one.look
        width: flownGlyph.implicitWidth + flownName.implicitWidth + 2 * card.pad + 8
        height: card.faceH
        radius: Zenon.windowRadius
        color: Zenon.layerBg
        border.width: 1
        border.color: Zenon.border
        Text {
          id: flownGlyph
          x: card.pad
          anchors.verticalCenter: parent.verticalCenter
          text: flown.one.look ? flown.one.look.glyph : ""
          color: flown.one.look && flown.one.look.ink !== undefined ? flown.one.look.ink : Zenon.white
          font.family: Zenon.faceFixed
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(16)
        }
        Text {
          id: flownName
          textFormat: Text.PlainText
          x: card.pad + flownGlyph.implicitWidth + 8
          anchors.verticalCenter: parent.verticalCenter
          text: flown.one.look ? flown.one.look.label : ""
          color: Zenon.white
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(15)
        }
      }
      SequentialAnimation {
        running: true
        PauseAnimation { duration: flown.lag }
        ParallelAnimation {
          NumberAnimation { target: flown; property: "x"; to: flown.back ? flown.one.x : flown.one.at.x; duration: flown.span; easing.type: Easing.InOutCubic }
          NumberAnimation { target: flown; property: "y"; to: flown.back ? flown.one.y : flown.one.at.y; duration: flown.span; easing.type: Easing.InOutCubic }
          NumberAnimation { target: flown; property: "scale"; to: flown.back ? 1 : flown.endScale; duration: flown.span; easing.type: Easing.InOutCubic }
        }
        // solid the whole way: leaving, it merges into the pile on the pointer
        NumberAnimation { target: flown; property: "opacity"; to: flown.back ? 1 : 0; duration: flown.back ? 0 : Zenon.fast }
        ScriptAction {
          script: {
            if (flown.back && flown.one.dim) flown.one.dim.destroy();
            flown.destroy();
          }
        }
      }
    }
  }

  // two cards peek out behind the front one, down and to the right
  readonly property int pile: card.count > 1 ? 4 * Math.min(card.count - 1, 2) : 0
  readonly property int faceH: 38

  opacity: 0
  z: -100
  x: -4000
  height: card.faceH + card.pile

  // SIZED FROM THE TEXT, NOT FROM A LAID-OUT ROW.
  //
  // grabToImage sizes its target from the item's width at the moment it is
  // CALLED, and the caller fills the labels in in that same tick. A Row sets
  // its own width during polish, at the end of the frame — so the first drag
  // of a session would carry a card cut to the width it had before the labels
  // existed. implicitWidth on a Text is re-evaluated synchronously, so by the
  // time grabToImage looks the width is right; which is also why the children
  // are anchored rather than positioned.
  readonly property real pad: 12
  readonly property bool pictured: card.thumb !== ""
  readonly property real lead: card.pictured ? thumbBox.width : glyphText.implicitWidth
  width: (card.pictured ? 5 : card.pad) + card.lead
    + (card.lead > 0 ? 8 : 0) + labelText.implicitWidth + card.pad
    + (card.count > 1 ? 8 + badge.width + 3 - card.pad : 0) + card.pile

  Repeater {
    model: card.pile / 4
    Rectangle {
      required property int index
      readonly property int back: card.pile / 4 - index
      x: back * 4
      y: back * 4
      width: face.width
      height: face.height
      radius: Zenon.windowRadius
      color: Zenon.layerBg
      border.width: 1
      border.color: Zenon.border
    }
  }

  Rectangle {
    id: face
    width: card.width - card.pile
    height: card.faceH
    radius: Zenon.windowRadius
    color: Zenon.layerBg
    border.width: 1
    border.color: Zenon.border
  }

  Text {
    id: glyphText
    visible: !card.pictured
    anchors.left: parent.left
    anchors.leftMargin: card.pad
    anchors.verticalCenter: face.verticalCenter
    text: card.glyph
    color: card.ink
    font.family: Zenon.faceFixed
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(16)
  }

  // Inset by the same 5px all round, so the picture sits in the card's
  // corner the way the card sits round it. Synchronous: it has to be drawn
  // in the one frame the grab looks at.
  ClippingRectangle {
    id: thumbBox
    visible: card.pictured
    anchors.left: parent.left
    anchors.leftMargin: 5
    anchors.verticalCenter: face.verticalCenter
    width: card.faceH - 10
    height: card.faceH - 10
    radius: Zenon.rad(3)
    color: Zenon.black
    Image {
      anchors.fill: parent
      source: card.thumb
      asynchronous: false
      cache: false
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: 2 * thumbBox.width
      sourceSize.height: 2 * thumbBox.height
    }
  }

  Text {
    textFormat: Text.PlainText
    id: labelText
    anchors.left: parent.left
    anchors.leftMargin: (card.pictured ? 5 : card.pad) + card.lead + (card.lead > 0 ? 8 : 0)
    anchors.verticalCenter: face.verticalCenter
    text: card.label
    color: Zenon.white
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(15)
  }

  // the count at the front card's far end
  Rectangle {
    id: badge
    anchors.right: face.right
    anchors.rightMargin: 3
    anchors.verticalCenter: face.verticalCenter
    visible: card.count > 1
    width: countText.implicitWidth + 12
    height: 20
    radius: Zenon.radiusControl
    color: Zenon.accent

    Text {
      id: countText
      anchors.centerIn: parent
      text: card.count
      color: Zenon.black
      font.family: Zenon.face
      font.pixelSize: Zenon.px(13)
      font.weight: Zenon.weight
    }
  }
}
