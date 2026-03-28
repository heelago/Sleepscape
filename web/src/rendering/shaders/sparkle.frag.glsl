#version 300 es
precision highp float;

in vec4 vColor;
in vec2 vUV;

out vec4 fragColor;

void main() {
    float dist = length(vUV);
    if (dist > 1.0) discard;

    // Sharp bright center with quick falloff
    float glow = exp(-6.0 * dist * dist);
    fragColor = vec4(vColor.rgb, vColor.a * glow);
}
