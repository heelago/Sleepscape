#version 300 es
precision highp float;

// Per-point data (from buffer)
layout(location = 0) in vec2 aPosition;      // point position
layout(location = 1) in float aPressure;
layout(location = 2) in float aAltitude;
layout(location = 3) in float aCumulDist;

// Per-point data for next point (segment endpoint)
layout(location = 4) in vec2 aPositionNext;
layout(location = 5) in float aPressureNext;
layout(location = 6) in float aAltitudeNext;
layout(location = 7) in float aCumulDistNext;

// Per-vertex quad corner
layout(location = 8) in vec2 aQuadCorner;     // (0 or 1, 0 or 1) -> (isRight, isBottom)

// Per-instance transform (3x3 matrix as 3 vec3s)
layout(location = 9)  in vec3 aTransformCol0;
layout(location = 10) in vec3 aTransformCol1;
layout(location = 11) in vec3 aTransformCol2;

uniform vec2 uCanvasSize;
uniform float uBrushSize;
uniform float uAlpha;
uniform uint uLineStyle;

out vec4 vColor;
out float vEdgeDist;
out float vCumulDist;
flat out uint vLineStyle;

uniform vec4 uColor;

void main() {
    float isRight = aQuadCorner.x;
    float isBottom = aQuadCorner.y;

    // Apply symmetry transform
    mat3 tx = mat3(aTransformCol0, aTransformCol1, aTransformCol2);
    vec2 a = (tx * vec3(aPosition, 1.0)).xy;
    vec2 b = (tx * vec3(aPositionNext, 1.0)).xy;

    // Pressure-mapped widths
    float w0 = uBrushSize * pow(aPressure, 0.6);
    float w1 = uBrushSize * pow(aPressureNext, 0.6);

    // Direction and normal
    vec2 dir = b - a;
    float len = length(dir);
    if (len < 0.001) {
        dir = vec2(1.0, 0.0);
    } else {
        dir /= len;
    }
    vec2 normal = vec2(-dir.y, dir.x);

    // Sketch mode: noise displacement
    if (uLineStyle == 4u) {
        float h = fract(sin(dot(vec2(aCumulDist * 0.3, float(gl_InstanceID) * 7.13), vec2(127.1, 311.7))) * 43758.5453);
        float h2 = fract(sin(dot(vec2(float(gl_InstanceID) * 3.7, aCumulDist), vec2(127.1, 311.7))) * 43758.5453);
        normal += vec2((h * 2.0 - 1.0) * 0.15, h2 * 0.15);
        normal = normalize(normal);
    }

    // Extend each segment endpoint by half-width along the direction
    // to create overlap at junctions (round cap effect)
    float capExt = (len > 0.5) ? 0.5 : 0.0;
    vec2 capA = a - dir * w0 * capExt;
    vec2 capB = b + dir * w1 * capExt;

    vec2 pos = mix(capA, capB, isRight);
    float width = mix(w0, w1, isRight);
    float offset = (isBottom < 0.5) ? -1.0 : 1.0;
    pos += normal * offset * width * 0.5;

    // Convert to NDC
    vec2 ndc;
    ndc.x = (pos.x / uCanvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pos.y / uCanvasSize.y) * 2.0;

    float pressure = mix(aPressure, aPressureNext, isRight);
    float mappedAlpha = 0.3 + 0.7 * pow(pressure, 0.5);

    gl_Position = vec4(ndc, 0.0, 1.0);
    vColor = vec4(uColor.rgb, uColor.a * mappedAlpha * uAlpha);
    vEdgeDist = offset;
    vCumulDist = mix(aCumulDist, aCumulDistNext, isRight);
    vLineStyle = uLineStyle;
}
