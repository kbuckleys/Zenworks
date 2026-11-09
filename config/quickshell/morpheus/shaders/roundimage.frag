// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ROUND IMAGE — a picture with rounded corners, sampled straight from the
// Image's own texture (see morpheus/RoundImage.qml). The crop or fit the
// Image would have drawn is `uvScale`/`uvOffset`; the corners are a rounded
// box's distance, a pixel of antialiasing wide; outside the picture (Fit's
// bands) is nothing.
// Built with: /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12
//             -o roundimage.frag.qsb roundimage.frag
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 frame;
    vec2 uvScale;
    vec2 uvOffset;
    float rad;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0 * uvScale + uvOffset;
    vec2 p = qt_TexCoord0 * frame;
    vec2 q = abs(p - frame * 0.5) - (frame * 0.5 - vec2(rad));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
    float cover = clamp(0.5 - d, 0.0, 1.0);
    vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
    vec4 c = texture(source, clamp(uv, 0.0, 1.0));      // premultiplied
    fragColor = c * (inside.x * inside.y * cover * qt_Opacity);
}
