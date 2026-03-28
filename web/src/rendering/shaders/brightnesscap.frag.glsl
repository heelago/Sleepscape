#version 300 es
precision highp float;

in vec2 vTexCoord;
uniform sampler2D uTexture;
uniform float uCap;
out vec4 fragColor;

void main() {
    vec4 color = texture(uTexture, vTexCoord);
    vec3 rgb = color.rgb;

    // RGB -> luminance via max/min (HSL-style)
    float cMax = max(rgb.r, max(rgb.g, rgb.b));
    float cMin = min(rgb.r, min(rgb.g, rgb.b));
    float L = (cMax + cMin) * 0.5;

    if (L <= uCap || cMax < 0.001) {
        fragColor = color; // already under cap or black
        return;
    }

    // Scale RGB so new luminance = cap
    float scale = uCap / max(L, 0.001);
    fragColor = vec4(rgb * scale, color.a);
}
