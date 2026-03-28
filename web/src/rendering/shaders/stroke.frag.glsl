#version 300 es
precision highp float;

in vec4 vColor;
in float vEdgeDist;
in float vCumulDist;
flat in uint vLineStyle;

out vec4 fragColor;

float hashNoise(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

void main() {
    float dist = abs(vEdgeDist);
    float falloff;

    if (vLineStyle == 1u) {
        // Soft glow: wider, softer edge
        falloff = exp(-2.0 * dist * dist);
    } else if (vLineStyle == 2u) {
        // Dashed: 20px on, 14px off
        float dashPattern = mod(vCumulDist, 34.0);
        if (dashPattern > 20.0) discard;
        falloff = 1.0 - smoothstep(0.5, 1.0, dist);
    } else if (vLineStyle == 3u) {
        // Dotted: segments discarded, dots carry the pattern
        discard;
    } else if (vLineStyle == 4u) {
        // Sketch: rough edges with noise
        float noise = hashNoise(vec2(vCumulDist * 0.5, dist * 20.0));
        float edgeNoise = dist + noise * 0.25;
        falloff = 1.0 - smoothstep(0.5, 1.0, edgeNoise);
        // Occasional gaps
        float gap = hashNoise(vec2(vCumulDist * 0.15, 0.0));
        if (gap > 0.92) falloff *= 0.3;
    } else {
        // Neon: default
        falloff = 1.0 - smoothstep(0.6, 1.0, dist);
    }

    fragColor = vec4(vColor.rgb, vColor.a * falloff);
}
