// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ── A PICTURE WITH ROUND CORNERS, AND NO TEXTURE OF ITS OWN ─────────────
// What a tile in a scrolled grid wants (picasso's Thumb, terminus' Tile):
//
//     Image { id: img; anchors.fill: parent; visible: false; ... }
//     RoundImage { anchors.fill: img; image: img; radius: 7 }
//
// WHY NOT A ClippingRectangle. That renders its content into a texture
// first (a ShaderEffectSource of it, plus a second one of its own
// rectangle), so every tile was two offscreen passes: made again whenever a
// tile took a new picture — a whole row each time the gallery's pool wraps
// round while scrolling — and a draw over a texture every frame. Measured
// offscreen on a 2560px gallery (2026-11-08): ~14 render passes a frame
// while scrolling. An Image is already a texture; this draws it once, the
// crop and the corners worked out in one shader, nothing in between.
//
// Lay it over the Image's own rectangle (the uv below is worked out from
// the Image's size and its painted size, centered as an Image aligns by
// default); the Image itself stays invisible and is only the texture.
// Fades and dims go on this item's opacity.

import QtQuick

ShaderEffect {
  id: round

  // the Image to draw (any Image: its fillMode is honored through its
  // painted size)
  property Image image: null
  property real radius: 0

  // the sampler the shader reads
  readonly property Image source: round.image
  readonly property real _pw: round.image && round.image.paintedWidth > 0 ? round.image.paintedWidth : 1
  readonly property real _ph: round.image && round.image.paintedHeight > 0 ? round.image.paintedHeight : 1
  readonly property real _sx: round.image ? round.image.width / round._pw : 1
  readonly property real _sy: round.image ? round.image.height / round._ph : 1
  readonly property vector2d uvScale: Qt.vector2d(round._sx, round._sy)
  readonly property vector2d uvOffset: Qt.vector2d((1 - round._sx) / 2, (1 - round._sy) / 2)
  readonly property vector2d frame: Qt.vector2d(Math.max(1, round.width), Math.max(1, round.height))
  readonly property real rad: Math.max(0, Math.min(round.radius, round.width / 2, round.height / 2))

  // nothing to draw until the picture is in
  visible: !!round.image && round.image.status === Image.Ready
  fragmentShader: Qt.resolvedUrl("shaders/roundimage.frag.qsb")
}
