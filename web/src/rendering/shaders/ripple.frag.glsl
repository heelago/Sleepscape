#version 300 es
precision highp float;

in vec4 vColor;
in vec2 vUV;

out vec4 fragColor;

void main() {
    float dist = length(vUV);
    if (dist > 1.0) discard;

    // Soft filled glow with ring accent at edge
    float glow = 1.0 - smoothstep(0.0, 1.0, dist);
    float ring = smoothstep(0.7, 0.85, dist) * (1.0 - smoothstep(0.9, 1.0, dist));
    float combined = glow * 0.5 + ring * 0.5;
    if (combined < 0.005) discard;

    fragColor = vec4(vColor.rgb, vColor.a * combined);
}
