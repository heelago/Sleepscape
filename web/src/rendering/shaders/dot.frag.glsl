#version 300 es
precision highp float;

in vec4 vColor;
in float vCumulDist;
flat in uint vLineStyle;

out vec4 fragColor;

float hashNoise(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

void main() {
    vec2 uv = gl_PointCoord * 2.0 - 1.0;
    float dist = length(uv);
    if (dist > 1.0) discard;

    float falloff;
    if (vLineStyle == 1u) {
        // Soft glow
        falloff = exp(-1.5 * dist * dist);
    } else if (vLineStyle == 4u) {
        // Sketch
        float noise = hashNoise(uv * 5.0 + vec2(vCumulDist));
        falloff = exp(-3.0 * dist * dist) * (0.7 + 0.3 * noise);
    } else {
        // Neon / default
        falloff = exp(-3.0 * dist * dist);
    }

    fragColor = vec4(vColor.rgb, vColor.a * falloff);
}
