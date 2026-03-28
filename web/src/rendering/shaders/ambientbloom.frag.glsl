#version 300 es
precision highp float;

in vec4 vColor;
in vec2 vUV;
in float vProgress;

out vec4 fragColor;

// Cheap hash (no sin)
float hash21(vec2 p) {
    return fract(fract(p.x * 0.1031 + p.y * 0.1030) *
                 fract(p.x * 0.0973 + p.y * 0.1099) * 43758.5453);
}

void main() {
    vec2 uv = vUV;
    float p = vProgress;
    vec4 col = vColor;

    float dist = length(uv);
    if (dist > 1.2) discard;

    // === PHASE 1: Gaussian glow (p 0.0 - 0.4) ===
    float growRadius = mix(0.15, 0.7, smoothstep(0.0, 0.5, p));
    float gauss = exp(-2.5 * (dist * dist) / (growRadius * growRadius));

    // === PHASE 2: Heat shimmer breakup (p 0.3 - 0.65) ===
    float breakup = 1.0;
    if (p > 0.3) {
        float breakAmt = smoothstep(0.3, 0.65, p);
        vec2 noiseUV = uv * 3.5;
        float minDist1 = 1.0;
        float minDist2 = 1.0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 cell = vec2(float(i), float(j));
                vec2 cellID = floor(noiseUV) + cell;
                vec2 cellPos = cell + vec2(
                    hash21(cellID * 1.17 + 0.3),
                    hash21(cellID * 2.43 + 7.1)
                ) - fract(noiseUV);
                float d = dot(cellPos, cellPos);
                if (d < minDist1) { minDist2 = minDist1; minDist1 = d; }
                else if (d < minDist2) { minDist2 = d; }
            }
        }
        float cellNoise = sqrt(minDist1);
        float cellFade = smoothstep(0.05, 0.35, cellNoise);
        breakup = mix(1.0, cellFade, breakAmt * 0.7);
    }

    // === PHASE 3: Ember particles (p 0.4 - 1.0) ===
    float embers = 0.0;
    if (p > 0.4) {
        float emberAmt = smoothstep(0.4, 0.7, p);
        float emberFade = 1.0 - smoothstep(0.75, 1.0, p);

        const int NUM_EMBERS = 18;
        for (int i = 0; i < NUM_EMBERS; i++) {
            float fi = float(i);
            float angle = hash21(vec2(fi * 1.73, fi * 0.51 + 3.7)) * 6.2832;
            float baseR = hash21(vec2(fi * 2.31 + 1.0, fi * 0.87)) * 0.35 + 0.08;
            float drift = baseR + p * (0.3 + hash21(vec2(fi * 0.63, fi * 1.92 + 5.0)) * 0.4);
            vec2 ePos = vec2(cos(angle), sin(angle)) * drift;
            float wander = (hash21(vec2(fi * 3.1, fi * 0.42 + 9.0)) - 0.5) * p * 0.6;
            ePos += vec2(-sin(angle), cos(angle)) * wander;

            float eDist = length(uv - ePos);
            float eSize = mix(0.06, 0.03, p) * (0.6 + hash21(vec2(fi * 1.1, 4.4)) * 0.8);
            float eDot = exp(-0.5 * (eDist * eDist) / (eSize * eSize));

            float eBirth = 0.35 + hash21(vec2(fi * 0.77, fi * 2.1)) * 0.3;
            float eDeath = 0.7 + hash21(vec2(fi * 1.44, fi * 0.33 + 2.0)) * 0.3;
            float eLife = smoothstep(eBirth, eBirth + 0.08, p) * (1.0 - smoothstep(eDeath, eDeath + 0.12, p));

            embers += eDot * eLife;
        }
        embers *= emberAmt * emberFade;
    }

    // === Composite ===
    float coreFade = 1.0 - smoothstep(0.5, 0.85, p);
    float core = gauss * breakup * coreFade;
    float brightness = mix(1.4, 0.6, smoothstep(0.0, 0.3, p));
    float alpha = clamp((core + embers * 0.8) * brightness, 0.0, 1.0) * col.a;

    if (alpha < 0.003) discard;

    // Slight warm-white center for early glow
    vec3 finalColor = mix(col.rgb, vec3(1.0), core * 0.3 * coreFade);
    fragColor = vec4(finalColor * alpha, alpha);
}
