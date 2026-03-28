#version 300 es
precision highp float;

layout(location = 0) in vec2 aQuadCorner;

// Per-instance transform (3x3 matrix as 3 vec3s)
layout(location = 1) in vec3 aTransformCol0;
layout(location = 2) in vec3 aTransformCol1;
layout(location = 3) in vec3 aTransformCol2;

uniform vec2 uCanvasSize;
uniform vec2 uCenter;
uniform vec2 uRadii;
uniform float uLineWidth;
uniform float uAlpha;
uniform vec4 uColor;

out vec4 vColor;
out vec2 vLocalPos;

void main() {
    float pad = uLineWidth * 2.0;
    vec2 localPos = aQuadCorner * (uRadii + vec2(pad));

    mat3 tx = mat3(aTransformCol0, aTransformCol1, aTransformCol2);
    vec2 transformedCenter = (tx * vec3(uCenter, 1.0)).xy;
    vec2 worldPos = transformedCenter + localPos;

    vec2 ndc;
    ndc.x = (worldPos.x / uCanvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (worldPos.y / uCanvasSize.y) * 2.0;

    gl_Position = vec4(ndc, 0.0, 1.0);
    vColor = vec4(uColor.rgb, uColor.a * uAlpha);
    vLocalPos = localPos;
}
