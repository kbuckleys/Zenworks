// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// TIME & DATE'S MAP (user, 2026-10-29): the continents in one ink
// (worldmap.js), the night side shaded with civil, nautical and full night
// as three steps of it, the sun where it stands overhead, and the time
// zone's city pinned. Hovering names the nearest city; a click makes its
// zone the computer's (Oracle.setTimeZone, which asks for the password).
// Repainted once a minute while shown — the terminator moves a quarter of a
// degree in that time, under a pixel at this size.
//
// ONE WORLD, NEVER STRETCHED (user, 2026-11-04: no repeat — it wrapped
// edge to edge from 2026-10-29): the world once, as large as the box lets
// it be at one scale both ways, centered in it, nothing past its edges.
// Its west edge is the Bering Strait, so Chukotka meets the rest of Russia
// across the date line rather than sticking out of the west (the copies
// either side are still drawn, and `box` clips them to that seam).
//
// THE NIGHT RUNS ON PAST THE BAND (user, 2026-10-31): the map's south edge
// is 60°S, but the terminator goes on to the pole — the canvas reaches
// `spill` further down, the shading carried on there and faded out, under
// the rows below (OracleWindow stacks the map's row under its neighbors;
// the list's clip still bounds it). The land, the cities and the pointer
// keep to the band itself.
//
// IN THE ACCENT (user, 2026-10-31): the land, its coast, the sun and the
// pinned city are `highlight` (Zenon.accent, the theme's or your own accent);
// only the names stay in the ink.

import QtQuick
import "../morpheus"
import "oracle.js" as Ora
import "worldmap.js" as World

Item {
  id: wm
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  // the longitude in the middle, chosen so the LEFT edge is the Bering
  // Strait: the Americas first, Chukotka last (user, 2026-10-29: a piece of
  // Russia stuck out of the west)
  readonly property real west: -169
  readonly property real center: wm.west + 180
  // pixels a degree, the same both ways: the height's, or the width's when
  // the whole world would not fit across
  readonly property real k: Math.max(0.01, Math.min(wm.height / (World.NORTH - World.SOUTH), wm.width / 360))
  // the world's own box in the canvas: centered across, and down when the
  // width is what bounds it
  readonly property real boxX: cv.width / 2 - 180 * wm.k
  readonly property real boxW: 360 * wm.k
  readonly property real oy: Math.max(0, (wm.height - (World.NORTH - World.SOUTH) * wm.k) / 2)
  // how far past the band's bottom the night goes on: down to the pole
  readonly property real spill: (World.SOUTH + 90) * wm.k
  // lon, lat → the map's pixels; `turn` is which copy of the world, −1 west
  function px(lon, turn) { return cv.width / 2 + (lon + 360 * (turn || 0) - wm.center) * wm.k; }
  function py(lat) { return wm.oy + (World.NORTH - lat) * wm.k; }
  // the copies any of which shows, and of a point the one nearest the middle
  function turns() {
    const out = [];
    for (let t = -3; t <= 3; ++t)
      if (wm.px(180, t) > 0 && wm.px(-180, t) < cv.width) out.push(t);
    return out;
  }
  function nearX(lon) {
    let best = wm.px(lon, 0);
    for (const t of [-1, 1]) {
      const x = wm.px(lon, t);
      if (Math.abs(x - cv.width / 2) < Math.abs(best - cv.width / 2)) best = x;
    }
    return best;
  }

  // PICKING, NOT SETTING (the setup assistant, 2026-11-04): with `picking`
  // a click says `picked` and pins `chosen`; the zone is set later, with
  // the assistant's other password asks. Without, it is Oracle's own.
  property bool picking: false
  property string chosen: ""
  signal picked(string zone)
  readonly property var here: {
    const zone = wm.picking && wm.chosen !== "" ? wm.chosen : (Oracle.revision, Oracle.timedate.zone);
    return Oracle.zones.find((z) => z.zone === zone) || null;
  }
  // the city under the pointer, while it is over the map
  property var hovered: null

  Canvas {
    id: cv
    width: wm.width
    height: wm.height + wm.spill
    // 17 ms a paint: straight away, so a resize never shows a stretched one
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d");
      ctx.reset();
      // h: the band's bottom; the night alone goes on to `full`
      const w = width, h = wm.height, full = height;
      if (w <= 0 || h <= 0) return;
      const ink = wm.highlight;
      const inkA = (a) => Qt.rgba(ink.r, ink.g, ink.b, a);
      const sun = Ora.subsolar(Date.now());
      const turns = wm.turns();
      // the one world: its copies and the night past its edges cut off
      ctx.save();
      ctx.beginPath();
      ctx.rect(wm.boxX, wm.oy, wm.boxW, full - wm.oy);
      ctx.clip();
      const land = () => {
        ctx.beginPath();
        for (const t of turns)
          for (const poly of World.LAND) {
            ctx.moveTo(wm.px(poly[0][0], t), wm.py(poly[0][1]));
            for (let i = 1; i < poly.length; ++i) ctx.lineTo(wm.px(poly[i][0], t), wm.py(poly[i][1]));
            ctx.closePath();
          }
      };
      // each level's day, column by column (Ora.daySpans): full night is
      // under −12°, then nautical and civil twilight, then the day
      const step = 3;
      const levels = [-12, -6, 0];
      const spans = levels.map((alt) => {
        const cols = [];
        for (let x = 0; x < w; x += step) cols.push(Ora.daySpans(wm.center + (x + step / 2 - w / 2) / wm.k, sun, alt));
        return cols;
      });

      // the land in the day's ink, then each level's night over it as
      // strips: the panel's ground to dim the land, the shade to darken all.
      // Plain rects, no clip — a clip of hundreds of strips cost a second
      ctx.fillRule = Qt.OddEvenFill;
      land();
      ctx.fillStyle = inkA(0.34);
      ctx.fill();
      ctx.fillRule = Qt.WindingFill;
      // each level's night as two smooth shapes, the part north of the
      // lit spans and the part south of them, with any dark gap between
      // two spans (twilight at both poles) as a strip
      const night = (cols) => {
        ctx.beginPath();
        const cx = (i) => i === 0 ? 0 : i === cols.length - 1 ? w : (i + 0.5) * step;
        const north = cols.map((sp) => sp.length ? Math.max(0, wm.py(Math.max(...sp.map((x) => x[1])))) : full);
        const south = cols.map((sp) => sp.length ? Math.min(full, wm.py(Math.min(...sp.map((x) => x[0])))) : full);
        ctx.moveTo(0, 0);
        north.forEach((y, i) => ctx.lineTo(cx(i), y));
        ctx.lineTo(w, 0);
        ctx.closePath();
        ctx.moveTo(0, full);
        south.forEach((y, i) => ctx.lineTo(cx(i), y));
        ctx.lineTo(w, full);
        ctx.closePath();
        cols.forEach((sp, i) => {
          if (sp.length < 2) return;
          const ss = sp.slice().sort((a, b) => b[1] - a[1]);
          for (let k = 1; k < ss.length; ++k)
            ctx.rect(i * step, wm.py(ss[k - 1][0]), step, wm.py(ss[k][1]) - wm.py(ss[k - 1][0]));
        });
      };
      for (const cols of spans) {
        night(cols);
        ctx.fillStyle = Zenon.alpha(Zenon.layerBg, 0.22);
        ctx.fill();
        ctx.fillStyle = Zenon.darken(0.06);
        ctx.fill();
      }
      // the spill fades out, so the night has no bottom edge of its own
      if (full > h) {
        const fade = ctx.createLinearGradient(0, h, 0, full);
        fade.addColorStop(0, Zenon.alpha(ink, 0));
        fade.addColorStop(1, Zenon.alpha(ink, 1));
        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = fade;
        ctx.fillRect(0, h, w, full - h);
        ctx.globalCompositeOperation = "source-over";
      }
      // and its edge, so a coast reads against the night too
      land();
      ctx.lineWidth = 1;
      ctx.lineJoin = "round";
      ctx.strokeStyle = inkA(0.22);
      ctx.stroke();

      // the sun, overhead where it is noon (on every copy that shows)
      const sy = wm.py(sun.lat);
      for (const t of turns) {
        const sx = wm.px(sun.lon, t);
        ctx.fillStyle = inkA(0.85);
        ctx.beginPath();
        ctx.arc(sx, sy, 4.5, 0, 2 * Math.PI);
        ctx.fill();
        ctx.strokeStyle = inkA(0.6);
        ctx.lineWidth = 1.5;
        ctx.lineCap = "round";
        ctx.beginPath();
        for (let r = 0; r < 8; ++r) {
          const a = r * Math.PI / 4;
          ctx.moveTo(sx + Math.cos(a) * 7.5, sy + Math.sin(a) * 7.5);
          ctx.lineTo(sx + Math.cos(a) * 10.5, sy + Math.sin(a) * 10.5);
        }
        ctx.stroke();
      }
      ctx.restore();
    }
  }

  // the accent changed (a theme, Accent color): the land is drawn in it;
  // a theme change alone moves the night's ground and shade
  onHighlightChanged: cv.requestPaint()
  Connections {
    target: Zenon
    function onThemeChanged() { cv.requestPaint(); }
  }
  Timer {
    interval: 60000
    running: wm.visible
    repeat: true
    onTriggered: cv.requestPaint()
  }
  onVisibleChanged: if (visible) cv.requestPaint()

  // ── a city on the map: a ring, and its name beside it ────────────────
  component CityMark: Item {
    id: cm
    property var city: null
    property bool pinned: false
    visible: cm.city !== null
    x: cm.city ? (cv.width, wm.nearX(cm.city.lon)) : 0
    y: cm.city ? wm.py(cm.city.lat) : 0
    Rectangle {
      visible: cm.pinned
      width: 7; height: 7; radius: 3.5
      x: -3.5; y: -3.5
      color: wm.highlight
    }
    Rectangle {
      width: 16; height: 16; radius: 8
      x: -8; y: -8
      color: "transparent"
      border.width: 1.5
      border.color: Zenon.alpha(wm.highlight, cm.pinned ? 0.7 : 0.45)
    }
    // the name, kept inside the map: left of the ring near the right edge,
    // under it near the top
    Rectangle {
      readonly property bool flip: cm.x + 14 + width > wm.width - 6
      x: flip ? -14 - width : 14
      y: cm.y - height / 2 < 6 ? 6 - cm.y : -height / 2
      width: name.implicitWidth + 14
      height: name.implicitHeight + 6
      radius: Zenon.radiusControl
      color: Zenon.alpha(Zenon.layerBg, 0.88)
      border.width: 1
      border.color: Zenon.border
      Text {
        id: name
        anchors.centerIn: parent
        text: cm.city ? cm.city.city : ""
        color: wm.fgColor
        font.family: wm.face
        font.weight: cm.pinned ? Zenon.titleWeight : Zenon.weight
        font.pixelSize: Zenon.px(13)
        textFormat: Text.PlainText
      }
    }
  }

  CityMark { city: wm.here; pinned: true; z: 1 }
  CityMark {
    z: 2
    city: wm.hovered && (!wm.here || wm.hovered.zone !== wm.here.zone) ? wm.hovered : null
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onPositionChanged: (m) => {
      // off the world, beside or above it: nothing
      if (m.x < wm.boxX || m.x > wm.boxX + wm.boxW || m.y < wm.oy || m.y > wm.py(World.SOUTH)) { wm.hovered = null; return; }
      wm.hovered = Ora.nearestZone(Oracle.zones, World.NORTH - (m.y - wm.oy) / wm.k,
                                   wm.center + (m.x - width / 2) / wm.k);
    }
    onExited: wm.hovered = null
    onClicked: if (wm.hovered) { if (wm.picking) wm.picked(wm.hovered.zone); else Oracle.setTimeZone(wm.hovered.zone); }
  }
}
