// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ONE PICTURE AS A TILE — the picker's grid, and the viewer's gallery and
// filmstrip. The cached thumbnail from morpheus/thumbs.js when there is one,
// the original when there is not, decoded at the size of the box either way.
//
//   path    the picture (its own file)
//   thumb   its cached thumbnail, "" while there is none yet, or thumbs.js'
//           NONE ("-") for a picture that will never have one (transparency)
//   wait    true while a thumbnail is still being made: the tile shows the
//           spinner rather than decoding the original in the meantime, which
//           for a directory of 24-megapixel photos is the difference between a
//           gallery that fills in and one that stalls

import QtQuick
import "../morpheus"
import "../morpheus/thumbs.js" as Thumbs

// ── ROUNDED WITHOUT A TEXTURE OF ITS OWN (2026-11-08) ──────────────────
// It was a ClippingRectangle: two offscreen passes per tile, made again each
// time a tile took a new picture — a row of them every time the gallery's
// pool wrapped round while scrolling. The ground is a plain Rectangle and the
// picture a RoundImage over the Image's own texture (see morpheus/RoundImage).
// Nothing inside is clipped any more; nothing inside reaches past the box.
Item {
  id: box

  property string path: ""
  property string thumb: ""
  // the thumbnail named would not open (swept from the shared pool, say):
  // the owner may make it again (audit 11-08)
  signal missed()
  property bool wait: false
  property int fillMode: Image.PreserveAspectCrop
  // the spinner while it loads — the picker's grid wants it; the viewer's
  // strip and gallery fill in quietly, terminus' way: nothing, then the fade
  property bool spinner: true
  // the fade in as it decodes — off in the viewer's strip, where stepping
  // through a directory made every tile scrolled into view develop again
  property bool fade: true
  // ── AS TERMINUS' GRID KEEPS ITS TILES ────────────────────────────────
  // `pooled`: a thumbnail decodes at the pool's own size (Thumbs.size()),
  // one cache key shared with `sizer` and with `keeper` — a terminus
  // ThumbKeeper, which holds the last screenfuls decoded — so a tile
  // scrolled back to is Ready on the frame it is made, and is not faded.
  // Tile-sized (the default, below) every new tile missed Qt's cache and
  // decoded the file again, sizer and picture apart: a gallery scrolled
  // through blank tiles filling in (user's capture, 2026-10-08).
  property bool pooled: false
  property var keeper: null

  // its own shape, width over height — for a caller that sizes the box to
  // the picture rather than cropping the picture to the box (the gallery,
  // terminus' way). Read off a sizer that is never drawn, at the pool's size:
  // the drawn image's implicit size follows the box, and the box would then
  // follow itself (see terminus' thumbNat).
  readonly property real ratio: sizer.implicitWidth > 0 && sizer.implicitHeight > 0
    ? sizer.implicitWidth / sizer.implicitHeight : 1
  readonly property bool measured: sizer.status === Image.Ready
  property bool measure: false

  readonly property int status: img.status
  // what the tile is showing, for a flight out of it (picasso's flyIn)
  readonly property url shownUrl: img.status === Image.Ready ? img.source : ""
  // a new thumbnail is a new chance
  onThumbChanged: img.thumbFailed = false

  property real radius: Zenon.windowRadius
  property color color: Zenon.surface

  Rectangle {
    anchors.fill: parent
    radius: box.radius
    color: box.color
    visible: box.color.a > 0
  }

  // the picture as drawn: the Image's texture, rounded, at the Image's fade
  RoundImage {
    anchors.fill: img
    image: img
    radius: box.radius
    opacity: img.opacity
  }

  Image {
    id: img
    anchors.fill: parent
    // only the texture: RoundImage above draws it
    visible: false
    // The cached thumbnail, not the original: these are ~70KB against 8MB,
    // and a grid rebuilds on every keystroke. Falls back to the original if a
    // thumbnail could not be generated, so a tile that cannot thumbnail still
    // works.
    property bool thumbFailed: false
    readonly property bool hasThumb: box.thumb !== "" && box.thumb !== "-" && !img.thumbFailed
    source: img.hasThumb ? "file://" + box.thumb
      : (box.wait || box.path === "" ? "" : Strings.fileUrl(box.path))
    onStatusChanged: {
      if (status === Image.Error && img.hasThumb) { img.thumbFailed = true; box.missed(); }
      if (status === Image.Ready && img.pool && box.keeper) box.keeper.keep(img.source);
    }
    readonly property bool pool: box.pooled && img.hasThumb
    fillMode: box.fillMode
    asynchronous: true
    // ── IT FADES IN, AS TERMINUS' TILES DO ─────────────────────────────
    // Nothing is drawn while it decodes, and the picture arrives over a
    // short fade, so a strip of them reads as developing rather than
    // popping in. IN ONLY: a source change or a recycled tile must not show
    // the last picture dissolving over the next, and a thumbnail already in
    // Qt's cache is Ready on the frame the tile is made, which a Behavior
    // does not animate — so a warmed directory still appears at once. Same rule
    // and numbers as terminus' thumbClip.
    opacity: img.status === Image.Ready ? 1 : 0
    Behavior on opacity {
      enabled: box.fade && img.opacity < 1
      NumberAnimation { duration: Zenon.normal; easing.type: Easing.OutCubic }
    }
    // Decoded at the size of the box it is drawn in, not at the size of the
    // file. The thumbnails are 480px square and a picker box is 222x98, so
    // without this every cell carries about five times the pixels it can show
    // — measured over the whole library that is 193MB of grid against 105MB,
    // and the grid does not give it back when it scrolls away.
    //
    // It matters far more on the fallback. A picture whose thumbnail is
    // missing is shown FROM THE ORIGINAL, and the originals here run to
    // 7276x4895 — 135MB of RGBA for one cell 222 pixels wide.
    //
    // Both axes, which is safe on Image: it scales to cover the box with the
    // aspect ratio intact. (AnimatedImage does not — see the Wall component
    // in PicassoDaemon.qml.)
    //
    // In steps of 64, as terminus' tiles are: the gallery's zoom resizes
    // every box over a quarter second, and a size that followed it exactly
    // decoded every visible picture again on every frame.
    sourceSize.width: img.pool ? Thumbs.size() : Math.ceil(box.width * img.Screen.devicePixelRatio / 64) * 64
    sourceSize.height: img.pool ? Thumbs.size() : Math.ceil(box.height * img.Screen.devicePixelRatio / 64) * 64
    // Safe to cache. The cache filename carries the source's mtime and size,
    // so a replaced picture is a different URL — Qt can no longer pin a
    // stale decode failure to it.
    cache: true
  }

  Image {
    id: sizer
    visible: false
    asynchronous: true
    source: box.measure ? img.source : ""
    sourceSize.width: Thumbs.size()
    sourceSize.height: Thumbs.size()
  }

  // An image Qt cannot decode used to leave a plain empty box,
  // indistinguishable from a very dark picture. Say so.
  // Both built only when shown: every Qt Text observes the viewport, and a
  // gallery's pool of tiles carrying two hidden ones each paid for them on
  // every frame of a scroll (2026-11-08). By x/y, as a sized Loader would
  // resize them.
  Loader {
    active: img.status === Image.Error
    sourceComponent: Component {
  Text {
    x: Math.round((box.width - width) / 2)
    y: Math.round((box.height - height) / 2)
    text: ""
    color: Zenon.accentMuted
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(22)
  }
    }
  }

  Loader {
    active: box.spinner && (img.status === Image.Loading || (box.wait && !img.hasThumb))
    sourceComponent: Component {
  Text {
    x: Math.round((box.width - width) / 2)
    y: Math.round((box.height - height) / 2)
    text: ""
    color: Zenon.accentMuted
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(18)
  }
    }
  }
}
