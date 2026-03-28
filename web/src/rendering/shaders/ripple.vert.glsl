#version 300 es
precision highp float;

// Per-instance ripple data
layout(location = 0) in vec2 aCenter;
layout(location = 1) in float aRadius;
layout(location = 2) in float aAlpha;
layout(location = 3) in vec4 aColor;

// Per-vertex quad corner
layout(location = 4) in vec2 aQuadCorner; // -1..1

uniform vec2 uCanvasSize;

out vec4 vColor;
out vec2 vUV;

void main() {
    vec2 local = aQuadCorner;
    vec2 pixelPos = aCenter + local * max(aRadius, 1.0);

    vec2 ndc;
    ndc.x = (pixelPos.x / uCanvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixelPos.y / uCanvasSize.y) * 2.0;

    gl_Position = vec4(ndc, 0.0, 1.0);
    vColor = vec4(aColor.rgb, aAlpha);
    vUV = local;
}
