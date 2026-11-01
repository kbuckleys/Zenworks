// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE WINDOW EFFECTS PAGE'S WINDOW (user, 2026-10-31: more pictures in
// oracle): a window as the suite wears it (layerBg, the corner, the border)
// over stripes of the accents, with hyprland's effects as the rows below
// set them — the blur behind it (morpheus' Frost: size and passes as the
// kernel, brightness and vibrancy), its shadow (RectangularShadow: range, render
// power, sharp, offset, scale; Surfaces' Window shadows), and the inner
// glow. Drag it about to see them against the stripes. Rounding power is
// a sub-pixel matter at a window's real corner, so the corner is drawn
// again, magnified, in a lens: the curve against the circle it bends from.
//
// A LIKENESS, NOT HYPRLAND'S SHADERS: close, not exact. Glass, noise and
// motion blur are not drawn.
//
// Loaded by URL from OracleWindow, not named as a type (see ComputerPanel).

import QtQuick
import QtQuick.Effects
import "../morpheus"

Item {
  id: fx

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.cyan

  // hyprland's own rows, with their defaults while it has not been read
  function hl(key, def) {
    const v = Oracle.hyprValues["hl:" + key];
    return v === undefined || v === null || v === "" ? def : v;
  }
  function num(key, def) { const v = Number(fx.hl(key, def)); return isNaN(v) ? def : v; }
  function on(key, def) { const v = fx.hl(key, def); return v === true || v === "true" || v === 1 || v === "1"; }

  readonly property bool blurOn: fx.on("decoration:blur:enabled", true)
  // dual kawase spreads about size × 2^passes
  readonly property int blurPx: Math.max(2, Math.min(64,
    Math.round(fx.num("decoration:blur:size", 8) * Math.pow(2, fx.num("decoration:blur:passes", 2) - 1) * 2)))
  readonly property var offset: {
    const p = String(fx.hl("decoration:shadow:offset", "0 10")).trim().split(/[\s,]+/).map(Number);
    return [isNaN(p[0]) ? 0 : p[0], isNaN(p[1]) ? 0 : p[1]];
  }
  readonly property real power: Math.max(1, fx.num("decoration:rounding_power", 2))
  readonly property bool glowOn: fx.on("decoration:glow:enabled", false)
  readonly property color glowInk: {
    const c = String(fx.hl("decoration:glow:color", ""));
    return c === "" ? Zenon.cyan : c;
  }

  Text {
    id: caption
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    textFormat: Text.PlainText
    text: "Drag the window. Close to hyprland's own, not exact."
    color: fx.dimColor
    font.family: fx.face
    font.pixelSize: Zenon.px(12)
  }

  Item {
    id: stage
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: caption.top
    anchors.bottomMargin: 10
    clip: true

    // ── the ground: the accents in stripes, as Surfaces' sample has ──
    Item {
      id: ground
      anchors.fill: parent
      Row {
        rotation: -20
        x: -stage.width * 0.2
        y: -stage.height * 2
        Repeater {
          model: Math.ceil(stage.width / 28) + 12
          Rectangle {
            required property int index
            width: 28
            height: stage.height * 5
            color: [Zenon.cyan, Zenon.pink, Zenon.sand, Zenon.blue][index % 4]
            opacity: 0.6
          }
        }
      }
    }

    // ── the shadow ──
    // as hyprland draws it: everywhere but under the window itself, which
    // is cut out where the window is, not where the offset shadow is (a
    // MenuShadow punches its own footprint, which an offset moves)
    readonly property real range: fx.num("decoration:shadow:range", 70)
    readonly property real grow: (fx.num("decoration:shadow:scale", 1) - 1) * Math.min(win.width, win.height) / 2
    Item {
      anchors.fill: parent
      visible: Oracle.hyprShadows && stage.range > 0
      layer.enabled: visible
      layer.effect: MultiEffect {
        maskEnabled: true
        maskInverted: true
        maskSource: hole
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }
      RectangularShadow {
        x: win.x + fx.offset[0] - stage.grow
        y: win.y + fx.offset[1] - stage.grow
        width: win.width + 2 * stage.grow
        height: win.height + 2 * stage.grow
        radius: Zenon.corner
        // render power: the higher, the sooner it fades
        blur: fx.on("decoration:shadow:sharp", false) ? 0
          : stage.range * 2 / Math.max(1, fx.num("decoration:shadow:render_power", 2))
        spread: fx.on("decoration:shadow:sharp", false) ? stage.range / 2 : 0
        color: Zenon.shade(0.48)
      }
    }
    // the window's footprint, for the cut
    Item {
      id: hole
      anchors.fill: parent
      visible: false
      layer.enabled: true
      Rectangle {
        x: win.x; y: win.y
        width: win.width; height: win.height
        radius: Zenon.corner
        color: Zenon.ink
      }
    }

    // ── the window ──
    Item {
      id: win
      x: (stage.width - width) / 2 - 60
      y: (stage.height - height) / 2
      width: Math.min(300, stage.width * 0.45)
      height: Math.min(150, stage.height - 40)

      Frost {
        anchors.fill: parent
        source: ground
        active: fx.blurOn
        blurMax: fx.blurPx
        radius: Zenon.corner
        scrim: 0
        brightness: (fx.num("decoration:blur:brightness", 1) - 1) * 0.6
        saturation: (fx.num("decoration:blur:vibrancy", 0.1696) - 0.17) * 1.5
        track: [win.x, win.y]
      }
      Rectangle {
        id: body
        anchors.fill: parent
        radius: Zenon.corner
        color: Zenon.layerBg
        border.width: Oracle.hyprBorder
        border.color: Zenon.alpha(Zenon.border, 0.65)
        Column {
          x: 14; y: 14
          spacing: 7
          Repeater {
            model: [0.6, 0.8, 0.5, 0.7]
            Rectangle {
              required property real modelData
              width: (body.width - 28) * modelData
              height: 6
              radius: 3
              color: Zenon.alpha(Zenon.ink, 0.25)
            }
          }
        }
      }
      // the inner glow: rings stepping in from the edge, fading at the
      // render power's rate
      Item {
        anchors.fill: parent
        visible: fx.glowOn && fx.num("decoration:glow:range", 10) > 0
        readonly property real range: Math.min(fx.num("decoration:glow:range", 10), Math.min(win.width, win.height) / 2)
        readonly property int steps: 8
        Repeater {
          model: parent.steps
          Rectangle {
            required property int index
            readonly property real step: parent.range / parent.steps
            anchors.fill: parent
            anchors.margins: index * step
            radius: Math.max(0, Zenon.corner - index * step)
            color: "transparent"
            border.width: Math.ceil(step)
            border.color: Zenon.alpha(fx.glowInk,
              0.55 * Math.pow(1 - index / parent.steps, fx.num("decoration:glow:render_power", 3)))
          }
        }
      }
      MouseArea {
        anchors.fill: parent
        drag.target: win
        drag.minimumX: -win.width / 2
        drag.maximumX: stage.width - win.width / 2
        drag.minimumY: -win.height / 2
        drag.maximumY: stage.height - win.height / 2
      }
    }

    // ── the corner, magnified ──
    Rectangle {
      id: lens
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 14
      width: 104
      height: 104
      radius: Zenon.radiusCard
      color: Zenon.layerBg
      border.width: 1
      border.color: Zenon.border
      // the corner fills most of the lens, whatever its size
      readonly property real k: 64 / Math.max(4, Zenon.corner)
      Canvas {
        id: curve
        x: 18; y: 18
        width: 72; height: 72
        readonly property var key: [fx.power, Zenon.corner, Zenon.ink.toString(), fx.highlight.toString()]
        onKeyChanged: requestPaint()
        onPaint: {
          const c = getContext("2d");
          c.reset();
          const r = Math.max(4, Zenon.corner) * lens.k;
          const path = (p) => {
            c.beginPath();
            c.moveTo(0, height);
            for (let i = 0; i <= 48; ++i) {
              const t = (i / 48) * Math.PI / 2;
              const ex = 2 / p;
              c.lineTo(r - r * Math.pow(Math.cos(t), ex), r - r * Math.pow(Math.sin(t), ex));
            }
            c.lineTo(width, 0);
          };
          // the circle it bends from, dashed
          c.strokeStyle = Zenon.alpha(Zenon.ink, 0.35);
          c.lineWidth = 1;
          c.setLineDash([3, 3]);
          path(2);
          c.stroke();
          c.setLineDash([]);
          c.strokeStyle = fx.highlight;
          c.lineWidth = 2;
          path(fx.power);
          c.stroke();
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        textFormat: Text.PlainText
        text: "Corner ×" + Math.round(lens.k)
        color: fx.dimColor
        font.family: fx.face
        font.pixelSize: Zenon.px(10)
      }
    }
  }
}
