#version 300 es
precision highp float;

in vec2 vTexCoord;
uniform sampler2D uTexture;
uniform float uCap;
out vec4 fragColor;

void main() {
    vec4 color = texture(uTexture, vTexCoord);
    vec3 rgb = color.rgb;

    // Tighter cap toward center so breath text stays readable
    // and the center doesn't blow out from overlapping strokes
    vec2 center = vTexCoord - 0.5;
    float distFromCenter = length(center) * 2.0; // 0 at center, ~1 at edges
    float centerDim = smoothstep(0.0, 0.55, distFromCenter);
    float effectiveCap = uCap * (0.55 + 0.45 * centerDim);

    // RGB -> luminance via max/min (HSL-style)
    float cMax = max(rgb.r, max(rgb.g, rgb.b));
    float cMin = min(rgb.r, min(rgb.g, rgb.b));
    float L = (cMax + cMin) * 0.5;

    if (L <= effectiveCap || cMax < 0.001) {
        fragColor = color; // already under cap or black
        return;
    }

    // Scale RGB so new luminance = effectiveCap
    float scale = effectiveCap / max(L, 0.001);
    fragColor = vec4(rgb * scale, color.a);
}
