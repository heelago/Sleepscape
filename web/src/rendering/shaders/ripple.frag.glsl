#version 300 es
precision highp float;

in vec4 vColor;
in vec2 vUV;

out vec4 fragColor;

void main() {
    float dist = length(vUV);
    if (dist > 1.0) discard;

    // Hair-thin ring, almost no fill
    float ring = smoothstep(0.82, 0.92, dist) * (1.0 - smoothstep(0.95, 1.0, dist));
    float combined = ring;
    if (combined < 0.005) discard;

    fragColor = vec4(vColor.rgb, vColor.a * combined);
}
