#version 300 es
precision highp float;

in vec4 vColor;
in vec2 vLocalPos;

uniform vec2 uRadii;
uniform float uLineWidth;

out vec4 fragColor;

void main() {
    vec2 safeRadii = max(uRadii, vec2(1.0));
    float dist = length(vLocalPos / safeRadii);

    float maxR = max(safeRadii.x, safeRadii.y);
    float edge = clamp(uLineWidth / maxR, 0.02, 0.35);

    float innerStart = 1.0 - edge * 2.0;
    float innerEnd = 1.0 - edge * 0.4;
    float outerStart = 1.0 + edge * 0.4;
    float outerEnd = 1.0 + edge * 2.0;

    float ring = smoothstep(innerStart, innerEnd, dist) * (1.0 - smoothstep(outerStart, outerEnd, dist));
    float fill = (1.0 - smoothstep(0.0, 1.0 - edge * 0.8, dist)) * 0.05;
    float alpha = max(ring, fill);
    if (alpha < 0.005) discard;

    fragColor = vec4(vColor.rgb, vColor.a * alpha);
}
