#version 300 es
precision highp float;

// Per-instance sparkle data
layout(location = 0) in vec2 aPosition;
layout(location = 1) in float aAlpha;
layout(location = 2) in float aSize;
layout(location = 3) in vec4 aColor;

// Per-vertex quad corner
layout(location = 4) in vec2 aQuadCorner; // -1..1

uniform vec2 uCanvasSize;

out vec4 vColor;
out vec2 vUV;

void main() {
    float halfSize = max(aSize * 0.5, 0.5);
    vec2 pixelPos = aPosition + aQuadCorner * halfSize;

    vec2 ndc;
    ndc.x = (pixelPos.x / uCanvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixelPos.y / uCanvasSize.y) * 2.0;

    gl_Position = vec4(ndc, 0.0, 1.0);
    vColor = vec4(aColor.rgb, aAlpha);
    vUV = aQuadCorner;
}
