// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// Confetti — CYNOSURE'S "confetti" (2026-11-03, Raycast's): cannons from
// the bottom corners of the focused screen and a shower over its top, in
// the theme's colors, about five seconds, then gone. The window takes no
// clicks and no keys (an empty mask), so whatever is under it goes on
// working. Drawn only while it flies: a whole-screen layer redrawn each
// frame is not kept running.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../morpheus"
import "../oracle"

Scope {
  id: confetti

  readonly property int lifeMs: 5000
  property bool flying: false

  function burst() {
    confetti.flying = false;
    Qt.callLater(() => confetti.flying = true);
  }

  LazyLoader {
    active: confetti.flying
    PanelWindow {
      id: win
      screen: Oracle.focusedScreen()
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "cynosure-confetti"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      anchors { left: true; right: true; top: true; bottom: true }
      color: "transparent"
      mask: Region {}

      property var bits: []
      property real born: 0
      readonly property var inks: [Zenon.accent, Zenon.red, Zenon.green, Zenon.yellow, Zenon.blue, Zenon.magenta, Zenon.white]

      // made on the first frame, when the window knows its size
      function make(w, h) {
        const out = [];
        const unit = Zenon.px(1);
        const piece = (x, y, vx, vy, i) => ({ x, y, vx, vy, spin: (Math.random() - 0.5) * 16, turn: Math.random() * Math.PI,
          size: (8 + Math.random() * 10) * unit, ink: win.inks[i % win.inks.length], wobble: Math.random() * 6,
          wide: Math.random() < 0.25 });
        // two cannons in the bottom corners, up and across most of the screen
        for (let i = 0; i < 240; i++) {
          const left = i % 2 === 0;
          const angle = 0.15 + Math.random() * 0.65;
          const speed = (1.3 + Math.random() * 1.1) * h;
          out.push(piece(left ? 0 : w, h, Math.sin(angle) * speed * (left ? 1 : -1), -Math.cos(angle) * speed, i));
        }
        // and a shower over the whole top edge, a beat later
        for (let i = 0; i < 160; i++)
          out.push(Object.assign(piece(Math.random() * w, -Zenon.px(20) - Math.random() * h * 0.6, (Math.random() - 0.5) * w * 0.15, 0, i),
            { late: 0.35 + Math.random() * 0.5 }));
        win.bits = out;
        win.born = Date.now();
      }

      Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
          if (win.bits.length === 0) { if (width > 0) win.make(width, height); return; }
          const ctx = getContext("2d");
          ctx.reset();
          const now = (Date.now() - win.born) / 1000;
          const g = height * 0.9;
          ctx.globalAlpha = Math.max(0, Math.min(1, (confetti.lifeMs / 1000 - now) / 1.0));
          for (const b of win.bits) {
            const t = now - (b.late || 0);
            if (t < 0) continue;
            // air slows them, gravity brings them down, a sway as they fall
            const drag = (1 - Math.exp(-1.6 * t)) / 1.6;
            const x = b.x + b.vx * drag + Math.sin(t * 3 + b.wobble) * b.size * 2.5;
            const y = b.y + b.vy * drag + 0.5 * g * t * t * (b.late ? 0.35 : 0.5);
            if (y > height + b.size * 4) continue;
            ctx.save();
            ctx.translate(x, y);
            ctx.rotate(b.turn + b.spin * t);
            ctx.scale(1, Math.cos(t * 7 + b.wobble));
            ctx.fillStyle = b.ink;
            if (b.wide) ctx.fillRect(-b.size, -b.size / 6, b.size * 2, b.size / 3);
            else ctx.fillRect(-b.size / 2, -b.size / 4, b.size, b.size / 2);
            ctx.restore();
          }
        }
      }
      FrameAnimation {
        running: true
        onTriggered: canvas.requestPaint()
      }
      Timer {
        interval: confetti.lifeMs
        running: true
        onTriggered: confetti.flying = false
      }
    }
  }
}
