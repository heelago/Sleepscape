#version 300 es
precision highp float;

in vec2 vTexCoord;

uniform vec2 uCanvasSize;
uniform vec2 uCenter;
uniform float uMaxRadius;
uniform float uTime;
uniform vec4 uColor;
uniform float uFadeIn;
uniform float uInhale;
uniform float uHold;
uniform float uExhale;
uniform float uHold2;

out vec4 fragColor;

void main() {
    vec2 fragPos = vTexCoord * uCanvasSize;
    vec2 delta = fragPos - uCenter;
    float dist = length(delta);

    // Compute total cycle and current phase
    float cycleDur = uInhale + uHold + uExhale + uHold2;
    if (cycleDur < 0.1) cycleDur = 12.0;
    float t = mod(uTime, cycleDur);

    float progress; // 0 = contracted, 1 = expanded
    float glow;

    float inhaleEnd = uInhale;
    float holdEnd = inhaleEnd + uHold;
    float exhaleEnd = holdEnd + uExhale;

    if (t < inhaleEnd) {
        float p = t / max(uInhale, 0.01);
        progress = 0.5 - 0.5 * cos(p * 3.14159);
        glow = 0.3 + 0.7 * progress;
    } else if (t < holdEnd) {
        progress = 1.0;
        float holdT = t - inhaleEnd;
        float pulse = 0.7 + 0.3 * sin(holdT * 2.0 * 3.14159);
        glow = pulse;
    } else if (t < exhaleEnd) {
        float p = (t - holdEnd) / max(uExhale, 0.01);
        progress = 0.5 + 0.5 * cos(p * 3.14159);
        glow = 0.3 + 0.7 * progress;
    } else {
        progress = 0.0;
        float hold2T = t - exhaleEnd;
        float pulse = 0.2 + 0.15 * sin(hold2T * 2.0 * 3.14159);
        glow = pulse;
    }

    // Ring position: 8px contracted to maxRadius expanded
    float ringPos = 8.0 + progress * (uMaxRadius - 8.0);

    // Razor-thin gaussian ring (sigma 1.2px)
    float ringDist = abs(dist - ringPos);
    float sigma = 1.2;
    float ring = exp(-ringDist * ringDist / (sigma * sigma * 2.0));

    // Dotted pattern: 60 dots around circumference
    float angle = atan(delta.y, delta.x);
    float dotCount = 60.0;
    float dotPattern = step(0.45, fract(angle * dotCount / (2.0 * 3.14159)));

    // When contracted, use solid ring (too small for dots)
    float isTiny = smoothstep(20.0, 8.0, ringPos);
    dotPattern = mix(dotPattern, 1.0, isTiny);

    float a = ring * dotPattern * 0.005 * glow * uFadeIn;
    if (a < 0.001) discard;
    fragColor = vec4(uColor.rgb, a);
}
