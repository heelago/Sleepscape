#version 300 es
precision highp float;

in vec2 vTexCoord;
uniform vec4 uCanvasInfo; // centerX, centerY, canvasW, canvasH
uniform vec4 uGlowColor;  // rgb + intensity in alpha
out vec4 fragColor;

void main() {
    vec2 center = uCanvasInfo.xy;
    vec2 size = uCanvasInfo.zw;
    vec2 pixelPos = vTexCoord * size;

    float dist = length(pixelPos - center) / length(size * 0.5);

    // Soft center glow
    float centerGlow = exp(-3.0 * dist * dist) * uGlowColor.a * 0.15;

    // Subtle radial vignette at edges
    float vignette = smoothstep(0.6, 1.4, dist) * 0.12;

    vec3 result = uGlowColor.rgb * centerGlow;
    float alpha = centerGlow - vignette;
    fragColor = vec4(result, max(alpha, -vignette));
}
