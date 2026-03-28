#version 300 es
precision highp float;

layout(location = 0) in vec2 aPosition;
layout(location = 1) in float aPressure;
layout(location = 2) in float aAltitude;
layout(location = 3) in float aCumulDist;

// Per-instance transform
layout(location = 4) in vec3 aTransformCol0;
layout(location = 5) in vec3 aTransformCol1;
layout(location = 6) in vec3 aTransformCol2;

uniform vec2 uCanvasSize;
uniform vec4 uColor;
uniform float uBrushSize;
uniform float uAlpha;
uniform uint uLineStyle;

out vec4 vColor;
out float vCumulDist;
flat out uint vLineStyle;

void main() {
    mat3 tx = mat3(aTransformCol0, aTransformCol1, aTransformCol2);
    vec2 pos = (tx * vec3(aPosition, 1.0)).xy;

    float mappedWidth = uBrushSize * pow(aPressure, 0.6);
    float mappedAlpha = 0.3 + 0.7 * pow(aPressure, 0.5);

    // Dot spacing for dotted mode
    bool showDot = true;
    if (uLineStyle == 3u) {
        float modDist = mod(aCumulDist, 12.0);
        showDot = (modDist < 3.0);
    }

    float radius = showDot ? max(mappedWidth * 2.0, 2.0) : 0.0;

    vec2 ndc;
    ndc.x = (pos.x / uCanvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pos.y / uCanvasSize.y) * 2.0;

    gl_Position = vec4(ndc, 0.0, 1.0);
    gl_PointSize = radius * 2.0;
    vColor = vec4(uColor.rgb, uColor.a * mappedAlpha * uAlpha);
    vCumulDist = aCumulDist;
    vLineStyle = uLineStyle;
}
