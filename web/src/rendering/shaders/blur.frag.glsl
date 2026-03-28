#version 300 es
precision highp float;

in vec2 vTexCoord;
uniform sampler2D uTexture;
uniform vec2 uDirection; // (1/w, 0) for horizontal, (0, 1/h) for vertical
out vec4 fragColor;

// 13-tap Gaussian kernel approximating sigma ~12 at half resolution
// Weights generated for sigma=6 (half-res equivalent of sigma=12 at full-res)
const float weights[7] = float[7](
    0.1964825501511404,
    0.2969069646728344,
    0.09447039785044732,
    0.010381362401148057,
    0.0003951544908498885,
    0.000005209953261900819,
    0.00000002378770757694803
);

void main() {
    vec4 result = texture(uTexture, vTexCoord) * weights[0];

    for (int i = 1; i < 7; i++) {
        vec2 offset = uDirection * float(i);
        result += texture(uTexture, vTexCoord + offset) * weights[i];
        result += texture(uTexture, vTexCoord - offset) * weights[i];
    }

    fragColor = result;
}
