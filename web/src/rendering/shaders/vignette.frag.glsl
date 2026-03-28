#version 300 es
precision highp float;

in vec2 vTexCoord;
out vec4 fragColor;

void main() {
    // Distance from center in UV space (0 at center, ~1.4 at corners)
    float dist = length((vTexCoord - 0.5) * 2.0);
    // Darken edges by up to 12%
    float darken = smoothstep(0.4, 1.4, dist) * 0.12;
    if (darken < 0.002) discard;
    fragColor = vec4(0.0, 0.0, 0.0, darken);
}
