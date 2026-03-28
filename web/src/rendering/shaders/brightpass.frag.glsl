#version 300 es
precision highp float;

in vec2 vTexCoord;
uniform sampler2D uTexture;
uniform vec4 uBgColor;
out vec4 fragColor;

void main() {
    vec4 color = texture(uTexture, vTexCoord);

    // Compute difference from background -- only strokes deviate from bg
    vec3 diff = abs(color.rgb - uBgColor.rgb);
    float deviation = dot(diff, vec3(0.333, 0.333, 0.333));

    // Only bloom pixels that differ significantly from background
    if (deviation < 0.03) {
        fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    float bloomStrength = smoothstep(0.03, 0.20, deviation);
    fragColor = vec4(color.rgb * bloomStrength * 1.3, color.a);
}
