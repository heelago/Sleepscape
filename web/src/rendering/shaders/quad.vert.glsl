#version 300 es
precision highp float;

out vec2 vTexCoord;

void main() {
    // Full-screen triangle (3 vertices, no buffer needed)
    // Covers [-1,1] NDC with correct UVs
    vec2 positions[6] = vec2[6](
        vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0),
        vec2(-1.0, 1.0),  vec2(1.0, -1.0), vec2(1.0, 1.0)
    );
    vec2 texCoords[6] = vec2[6](
        vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 1.0),
        vec2(0.0, 1.0), vec2(1.0, 0.0), vec2(1.0, 1.0)
    );

    gl_Position = vec4(positions[gl_VertexID], 0.0, 1.0);
    vTexCoord = texCoords[gl_VertexID];
}
