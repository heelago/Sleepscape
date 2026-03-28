#include <metal_stdlib>
using namespace metal;

// ═══════════════════════════════════════════
//  Shared types
// ═══════════════════════════════════════════

struct QuadVertex {
    float4 position [[position]];
    float2 texCoord;
};

// Uniforms for stroke rendering (matches Swift GPUStrokeUniforms — 64 bytes)
struct StrokeUniforms {
    float2 canvasSize;      // offset 0
    float4 color;           // offset 16 (float4 = 16-byte aligned)
    float brushSize;        // offset 32
    float alpha;            // offset 36
    float glowRadius;       // offset 40
    uint  lineStyle;        // offset 44  (0=neon, 1=softGlow, 2=dashed, 3=dotted, 4=sketch)
};

// Per-point data for stroke segments
struct StrokePoint {
    float2 position;
    float pressure;
    float altitude;
    float cumulDist;       // cumulative distance along stroke
    float _pad;            // padding to 24 bytes
};

// Line style constants
constant uint STYLE_NEON      = 0;
constant uint STYLE_SOFT_GLOW = 1;
constant uint STYLE_DASHED    = 2;
constant uint STYLE_DOTTED    = 3;
constant uint STYLE_SKETCH    = 4;

// Simple hash for noise
float hashNoise(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

// ═══════════════════════════════════════════
//  Full-screen quad (texture compositing)
// ═══════════════════════════════════════════

vertex QuadVertex quadVertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1),  float2(1, -1), float2(1, 1)
    };
    float2 texCoords[6] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(0, 0), float2(1, 1), float2(1, 0)
    };

    QuadVertex out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 textureFragmentShader(QuadVertex in [[stage_in]],
                                       texture2d<float> tex [[texture(0)]]) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear);
    return tex.sample(texSampler, in.texCoord);
}

// Bright-pass extraction for bloom
// Uses a background color uniform so bloom only extracts STROKES, not the background itself.
fragment float4 brightPassFragment(QuadVertex in [[stage_in]],
                                    texture2d<float> tex [[texture(0)]],
                                    constant float4 &bgColor [[buffer(0)]]) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear);
    float4 color = tex.sample(texSampler, in.texCoord);

    // Compute difference from background — only strokes deviate from bg
    float3 diff = abs(color.rgb - bgColor.rgb);
    float deviation = dot(diff, float3(0.333, 0.333, 0.333));  // avg channel difference

    // Only bloom pixels that differ significantly from background
    if (deviation < 0.03) {
        return float4(0, 0, 0, 0);  // background pixel — no bloom
    }

    float bloomStrength = smoothstep(0.03, 0.20, deviation);
    return float4(color.rgb * bloomStrength * 1.3, color.a);
}

// Center glow + radial edge fade overlay
// buffer(0) = float4(centerX, centerY, canvasW, canvasH)
// buffer(1) = float4(glowColor.rgb, intensity)
fragment float4 centerGlowFragment(QuadVertex in [[stage_in]],
                                     constant float4 &canvasInfo [[buffer(0)]],
                                     constant float4 &glowColor  [[buffer(1)]]) {
    float2 center = canvasInfo.xy;
    float2 size = canvasInfo.zw;
    float2 pixelPos = in.texCoord * size;

    float dist = length(pixelPos - center) / length(size * 0.5);

    // Soft center glow — strongest at center, falls off radially
    float centerGlow = exp(-3.0 * dist * dist) * glowColor.a * 0.15;

    // Subtle radial vignette at edges
    float vignette = smoothstep(0.6, 1.4, dist) * 0.12;

    // Combine: add glow, subtract vignette
    float3 result = glowColor.rgb * centerGlow;
    float alpha = centerGlow - vignette;
    return float4(result, max(alpha, -vignette));
}


// ═══════════════════════════════════════════
//  Segment rendering with symmetry + line styles
//  buffer(0) = StrokePoint array
//  buffer(1) = StrokeUniforms
//  buffer(2) = float3x3 transforms array
//  buffer(3) = uint segmentCount
// ═══════════════════════════════════════════

struct SegmentVertex {
    float4 position [[position]];
    float4 color;
    float edgeDist;
    float cumulDist;       // for dashed/dotted patterns
    uint  lineStyle;       // passed through to fragment
};

vertex SegmentVertex symmetrySegmentVertex(uint vertexID [[vertex_id]],
                                            uint instanceID [[instance_id]],
                                            constant StrokePoint *points [[buffer(0)]],
                                            constant StrokeUniforms &uniforms [[buffer(1)]],
                                            constant float3x3 *transforms [[buffer(2)]],
                                            constant uint &segmentCount [[buffer(3)]]) {
    uint segIdx = instanceID % segmentCount;
    uint txIdx = instanceID / segmentCount;

    StrokePoint p0 = points[segIdx];
    StrokePoint p1 = points[segIdx + 1];

    // Apply symmetry transform
    float3x3 tx = transforms[txIdx];
    float3 tp0 = tx * float3(p0.position, 1.0);
    float3 tp1 = tx * float3(p1.position, 1.0);
    float2 a = tp0.xy;
    float2 b = tp1.xy;

    // Pressure-mapped widths
    float w0 = uniforms.brushSize * pow(p0.pressure, 0.6);
    float w1 = uniforms.brushSize * pow(p1.pressure, 0.6);

    // Direction and normal
    float2 dir = b - a;
    float len = length(dir);
    if (len < 0.001) {
        dir = float2(1, 0);
    } else {
        dir /= len;
    }
    float2 normal = float2(-dir.y, dir.x);

    // Sketch mode: add subtle noise displacement to normal
    if (uniforms.lineStyle == STYLE_SKETCH) {
        float noiseVal = hashNoise(float2(p0.cumulDist * 0.3, float(segIdx) * 7.13)) * 2.0 - 1.0;
        normal += float2(noiseVal * 0.15, hashNoise(float2(float(segIdx) * 3.7, p0.cumulDist)) * 0.15);
        normal = normalize(normal);
    }

    // 6 vertices: two triangles forming a quad
    float isRight, isBottom;
    switch (vertexID) {
        case 0: isRight = 0; isBottom = 0; break;
        case 1: isRight = 0; isBottom = 1; break;
        case 2: isRight = 1; isBottom = 0; break;
        case 3: isRight = 0; isBottom = 1; break;
        case 4: isRight = 1; isBottom = 0; break;
        case 5: isRight = 1; isBottom = 1; break;
        default: isRight = 0; isBottom = 0; break;
    }

    float2 pos = mix(a, b, isRight);
    float width = mix(w0, w1, isRight);
    float offset = (isBottom == 0) ? -1.0 : 1.0;
    pos += normal * offset * width * 0.5;

    // Convert to NDC
    float2 ndc;
    ndc.x = (pos.x / uniforms.canvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pos.y / uniforms.canvasSize.y) * 2.0;

    float mappedAlpha = 0.3 + (0.7 * pow(mix(p0.pressure, p1.pressure, isRight), 0.5));

    SegmentVertex out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = float4(uniforms.color.rgb, uniforms.color.a * mappedAlpha * uniforms.alpha);
    out.edgeDist = offset;
    out.cumulDist = mix(p0.cumulDist, p1.cumulDist, isRight);
    out.lineStyle = uniforms.lineStyle;
    return out;
}

fragment float4 segmentFragmentShader(SegmentVertex in [[stage_in]]) {
    float dist = abs(in.edgeDist);

    // Base edge falloff
    float falloff;

    switch (in.lineStyle) {
        case STYLE_SOFT_GLOW:
            // Wider, softer edge — more diffuse glow
            falloff = exp(-2.0 * dist * dist);
            break;

        case STYLE_DASHED: {
            // Dashed pattern: 20px on, 14px off
            float dashPattern = fmod(in.cumulDist, 34.0);
            if (dashPattern > 20.0) discard_fragment();
            falloff = 1.0 - smoothstep(0.5, 1.0, dist);
            break;
        }

        case STYLE_DOTTED:
            // Dotted: render very little from segments, dots carry the pattern
            discard_fragment();
            break;

        case STYLE_SKETCH: {
            // Rough edges with noise texture
            float noise = hashNoise(float2(in.cumulDist * 0.5, dist * 20.0));
            float edgeNoise = dist + noise * 0.25;
            falloff = 1.0 - smoothstep(0.5, 1.0, edgeNoise);
            // Occasional gaps for hand-drawn feel
            float gap = hashNoise(float2(in.cumulDist * 0.15, 0.0));
            if (gap > 0.92) falloff *= 0.3;
            break;
        }

        default: // STYLE_NEON
            falloff = 1.0 - smoothstep(0.6, 1.0, dist);
            break;
    }

    return float4(in.color.rgb, in.color.a * falloff);
}


// ═══════════════════════════════════════════
//  Dot rendering with symmetry + line styles
// ═══════════════════════════════════════════

struct DotVertex {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
    float cumulDist;
    uint  lineStyle;
};

vertex DotVertex symmetryDotVertex(uint vertexID [[vertex_id]],
                                    uint instanceID [[instance_id]],
                                    constant StrokePoint *points [[buffer(0)]],
                                    constant StrokeUniforms &uniforms [[buffer(1)]],
                                    constant float3x3 *transforms [[buffer(2)]],
                                    constant uint &pointCount [[buffer(3)]]) {
    uint ptIdx = instanceID % pointCount;
    uint txIdx = instanceID / pointCount;

    StrokePoint pt = points[ptIdx];

    // Apply symmetry transform
    float3x3 tx = transforms[txIdx];
    float3 transformed = tx * float3(pt.position, 1.0);
    float2 pos = transformed.xy;

    float pressure = pt.pressure;
    float mappedWidth = uniforms.brushSize * pow(pressure, 0.6);
    float mappedAlpha = 0.3 + (0.7 * pow(pressure, 0.5));

    // Dot spacing for dotted mode
    float dotSpacing = 12.0;
    bool showDot = true;
    if (uniforms.lineStyle == STYLE_DOTTED) {
        float modDist = fmod(pt.cumulDist, dotSpacing);
        showDot = (modDist < 3.0); // show dot for first 3px of each 12px cycle
    }

    float radius = showDot ? max(mappedWidth * 2.0, 2.0) : 0.0;

    float2 ndc;
    ndc.x = (pos.x / uniforms.canvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pos.y / uniforms.canvasSize.y) * 2.0;

    DotVertex out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = float4(uniforms.color.rgb, uniforms.color.a * mappedAlpha * uniforms.alpha);
    out.pointSize = radius * 2.0;
    out.cumulDist = pt.cumulDist;
    out.lineStyle = uniforms.lineStyle;
    return out;
}

fragment float4 dotFragmentShader(DotVertex in [[stage_in]],
                                    float2 pointCoord [[point_coord]]) {
    float2 uv = pointCoord * 2.0 - 1.0;
    float dist = length(uv);
    if (dist > 1.0) discard_fragment();

    float falloff;
    switch (in.lineStyle) {
        case STYLE_SOFT_GLOW:
            falloff = exp(-1.5 * dist * dist);  // softer, wider
            break;
        case STYLE_SKETCH: {
            float noise = hashNoise(uv * 5.0 + float2(in.cumulDist));
            falloff = exp(-3.0 * dist * dist) * (0.7 + 0.3 * noise);
            break;
        }
        default:
            falloff = exp(-3.0 * dist * dist);
            break;
    }

    return float4(in.color.rgb, in.color.a * falloff);
}


// ═══════════════════════════════════════════
//  Ripple rendering — instanced quads (no point size limit)
// ═══════════════════════════════════════════

struct RippleData {
    float2 center;
    float radius;
    float alpha;
    float4 color;
    int rings;
};

struct RippleVertex {
    float4 position [[position]];
    float4 color;
    float2 uv;     // -1..1 local coords
};

// 6 vertices per instance (2 triangles = 1 screen-aligned quad)
vertex RippleVertex rippleVertex(uint vertexID [[vertex_id]],
                                  uint instanceID [[instance_id]],
                                  constant RippleData *rings [[buffer(0)]],
                                  constant float2 &canvasSize [[buffer(1)]]) {
    RippleData r = rings[instanceID];

    // Quad corners in local space: -1..1
    float2 corners[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1),  float2(1, -1), float2(1, 1)
    };
    float2 local = corners[vertexID];

    // Expand quad to cover the ripple radius in pixel space
    float2 pixelPos = r.center + local * max(r.radius, 1.0);

    // Convert to NDC
    float2 ndc;
    ndc.x = (pixelPos.x / canvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixelPos.y / canvasSize.y) * 2.0;

    RippleVertex out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = float4(r.color.rgb, r.alpha);
    out.uv = local;
    return out;
}

fragment float4 rippleFragment(RippleVertex in [[stage_in]]) {
    float dist = length(in.uv);
    if (dist > 1.0) discard_fragment();

    // Soft filled glow with ring accent at edge
    float glow = 1.0 - smoothstep(0.0, 1.0, dist);
    float ring = smoothstep(0.7, 0.85, dist) * (1.0 - smoothstep(0.9, 1.0, dist));
    float combined = glow * 0.5 + ring * 0.5;
    if (combined < 0.005) discard_fragment();

    return float4(in.color.rgb, in.color.a * combined);
}


// ═══════════════════════════════════════════
//  Ambient Bloom rendering — instanced quads
// ═══════════════════════════════════════════

struct AmbientBloomData {
    float2 center;
    float radius;
    float alpha;
    float4 color;
    float progress;   // 0→1 lifecycle progress (radius / maxRadius)
    float3 _pad;      // align to match Swift struct (48 bytes)
};

struct AmbientBloomVertex {
    float4 position [[position]];
    float4 color;
    float2 uv;
    float progress;
};

vertex AmbientBloomVertex ambientBloomVertex(uint vertexID [[vertex_id]],
                                              uint instanceID [[instance_id]],
                                              constant AmbientBloomData *blooms [[buffer(0)]],
                                              constant float2 &canvasSize [[buffer(1)]]) {
    AmbientBloomData b = blooms[instanceID];

    float2 corners[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1),  float2(1, -1), float2(1, 1)
    };
    float2 local = corners[vertexID];
    float2 pixelPos = b.center + local * max(b.radius, 2.0);

    float2 ndc;
    ndc.x = (pixelPos.x / canvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixelPos.y / canvasSize.y) * 2.0;

    AmbientBloomVertex out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = float4(b.color.rgb, b.alpha);
    out.uv = local;
    out.progress = b.progress;
    return out;
}

fragment float4 ambientBloomFragment(AmbientBloomVertex in [[stage_in]]) {
    float2 uv = in.uv;
    float p = in.progress;
    float4 col = in.color;

    float dist = length(uv);
    if (dist > 1.2) discard_fragment();

    // --- Hash function (cheap, no sin) ---
    #define HASH21(p) fract(fract((p).x * 0.1031 + (p).y * 0.1030) * \
        fract((p).x * 0.0973 + (p).y * 0.1099) * 43758.5453)

    // === PHASE 1: Gaussian glow (p 0.0 - 0.4) ===
    // UV is -1..1, so sigma needs to be in that range
    float growRadius = mix(0.15, 0.7, smoothstep(0.0, 0.5, p));
    float gauss = exp(-2.5 * (dist * dist) / (growRadius * growRadius));

    // === PHASE 2: Heat shimmer breakup (p 0.3 - 0.65) ===
    float breakup = 1.0;
    if (p > 0.3) {
        float breakAmt = smoothstep(0.3, 0.65, p);
        float2 noiseUV = uv * 3.5;
        float minDist1 = 1.0;
        float minDist2 = 1.0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                float2 cell = float2(float(i), float(j));
                float2 cellID = floor(noiseUV) + cell;
                float2 cellPos = cell + float2(
                    HASH21(cellID * 1.17 + 0.3),
                    HASH21(cellID * 2.43 + 7.1)
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
            float angle = HASH21(float2(fi * 1.73, fi * 0.51 + 3.7)) * 6.2832;
            float baseR = HASH21(float2(fi * 2.31 + 1.0, fi * 0.87)) * 0.35 + 0.08;
            float drift = baseR + p * (0.3 + HASH21(float2(fi * 0.63, fi * 1.92 + 5.0)) * 0.4);
            float2 ePos = float2(cos(angle), sin(angle)) * drift;
            float wander = (HASH21(float2(fi * 3.1, fi * 0.42 + 9.0)) - 0.5) * p * 0.6;
            ePos += float2(-sin(angle), cos(angle)) * wander;

            float eDist = length(uv - ePos);
            float eSize = mix(0.06, 0.03, p) * (0.6 + HASH21(float2(fi * 1.1, 4.4)) * 0.8);
            float eDot = exp(-0.5 * (eDist * eDist) / (eSize * eSize));

            float eBirth = 0.35 + HASH21(float2(fi * 0.77, fi * 2.1)) * 0.3;
            float eDeath = 0.7 + HASH21(float2(fi * 1.44, fi * 0.33 + 2.0)) * 0.3;
            float eLife = smoothstep(eBirth, eBirth + 0.08, p) * (1.0 - smoothstep(eDeath, eDeath + 0.12, p));

            embers += eDot * eLife;
        }
        embers *= emberAmt * emberFade;
    }

    // === Composite ===
    float coreFade = 1.0 - smoothstep(0.5, 0.85, p);
    float core = gauss * breakup * coreFade;
    float brightness = mix(1.4, 0.6, smoothstep(0.0, 0.3, p));
    float alpha = saturate((core + embers * 0.8) * brightness) * col.a;

    if (alpha < 0.003) discard_fragment();

    // Slight warm-white center for early glow
    float3 finalColor = mix(col.rgb, float3(1.0), core * 0.3 * coreFade);
    return float4(finalColor * alpha, alpha);

    #undef HASH21
}


// ═══════════════════════════════════════════
//  Sparkle particles — instanced quads
// ═══════════════════════════════════════════

struct SparkleData {
    float2 position;
    float alpha;
    float size;
    float4 color;
};

struct SparkleVertex {
    float4 position [[position]];
    float4 color;
    float2 uv;
};

vertex SparkleVertex sparkleVertex(uint vertexID [[vertex_id]],
                                    uint instanceID [[instance_id]],
                                    constant SparkleData *sparkles [[buffer(0)]],
                                    constant float2 &canvasSize [[buffer(1)]]) {
    SparkleData s = sparkles[instanceID];

    float2 corners[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1),  float2(1, -1), float2(1, 1)
    };
    float2 local = corners[vertexID];
    float halfSize = max(s.size * 0.5, 0.5);
    float2 pixelPos = s.position + local * halfSize;

    float2 ndc;
    ndc.x = (pixelPos.x / canvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixelPos.y / canvasSize.y) * 2.0;

    SparkleVertex out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = float4(s.color.rgb, s.alpha);
    out.uv = local;
    return out;
}

fragment float4 sparkleFragment(SparkleVertex in [[stage_in]]) {
    float dist = length(in.uv);
    if (dist > 1.0) discard_fragment();

    // Sharp bright center with quick falloff
    float glow = exp(-6.0 * dist * dist);
    return float4(in.color.rgb, in.color.a * glow);
}


// ═══════════════════════════════════════════
//  Ellipse rendering
// ═══════════════════════════════════════════

struct EllipseUniforms {
    float2 canvasSize;
    float2 _pad0;
    float4 color;
    float2 center;
    float2 radii;
    float rotation;
    float lineWidth;
    float alpha;
    float _pad1;
};

struct EllipseVertex {
    float4 position [[position]];
    float4 color;
    float2 localUV;
};

vertex EllipseVertex ellipseVertex(uint vertexID [[vertex_id]],
                                    uint instanceID [[instance_id]],
                                    constant EllipseUniforms &uniforms [[buffer(0)]],
                                    constant float3x3 *transforms [[buffer(1)]]) {
    float pad = uniforms.lineWidth * 2.0;
    float maxR = max(uniforms.radii.x, uniforms.radii.y) + pad;

    float2 corners[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1),  float2(1, -1), float2(1, 1)
    };
    float2 localPos = corners[vertexID] * maxR;

    float cosR = cos(uniforms.rotation);
    float sinR = sin(uniforms.rotation);
    float2 rotated = float2(
        localPos.x * cosR - localPos.y * sinR,
        localPos.x * sinR + localPos.y * cosR
    );

    float3x3 tx = transforms[instanceID];
    float3 transformedCenter = tx * float3(uniforms.center, 1.0);
    float2 worldPos = transformedCenter.xy + rotated;

    float2 ndc;
    ndc.x = (worldPos.x / uniforms.canvasSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (worldPos.y / uniforms.canvasSize.y) * 2.0;

    EllipseVertex out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = float4(uniforms.color.rgb, uniforms.color.a * uniforms.alpha);
    out.localUV = corners[vertexID];
    return out;
}

fragment float4 ellipseFragment(EllipseVertex in [[stage_in]]) {
    float dist = length(in.localUV);
    float ring = smoothstep(0.85, 0.90, dist) * (1.0 - smoothstep(0.95, 1.0, dist));
    float fill = (1.0 - smoothstep(0.0, 0.95, dist)) * 0.05;
    float alpha = max(ring, fill);
    if (alpha < 0.005) discard_fragment();
    return float4(in.color.rgb, in.color.a * alpha);
}

// ═══════════════════════════════════════════
//  Mandala border glow
// ═══════════════════════════════════════════

struct MandalaBorderUniforms {
    float2 canvasSize;
    float2 center;       // pixel-space center
    float  radius;       // mandala radius in pixels
    float4 color;        // ink color (rgb + a)
};

fragment float4 mandalaBorderFragment(QuadVertex in [[stage_in]],
                                      constant MandalaBorderUniforms &u [[buffer(0)]]) {
    float2 fragPos = in.texCoord * u.canvasSize;
    float dist = length(fragPos - u.center);
    float ringDist = abs(dist - u.radius);
    // Very wide, ghostly glow — barely visible boundary guide
    float glow = exp(-ringDist * ringDist / (25.0 * 25.0 * 2.0));
    float a = glow * 0.04;  // whisper-thin
    if (a < 0.002) discard_fragment();
    return float4(u.color.rgb, a);
}

// ═══════════════════════════════════════════
//  Breath pulse — 4-phase breathing ring
//  Inhale: ring expands, glow brightens
//  Hold:   ring stays at max, glow stays bright
//  Exhale: ring contracts, glow dims
//  Hold2:  ring stays small, glow stays dim
//  Dotted, razor-thin, center always unfilled.
// ═══════════════════════════════════════════

struct BreathPulseUniforms {
    float2 canvasSize;
    float2 center;
    float  maxRadius;
    float  time;
    float4 color;
    float  fadeIn;
    float  inhale;       // seconds
    float  hold;         // seconds
    float  exhale;       // seconds
    float  hold2;        // seconds
};

fragment float4 breathPulseFragment(QuadVertex in [[stage_in]],
                                    constant BreathPulseUniforms &u [[buffer(0)]]) {
    float2 fragPos = in.texCoord * u.canvasSize;
    float2 delta = fragPos - u.center;
    float dist = length(delta);

    // Compute total cycle and current phase
    float cycleDur = u.inhale + u.hold + u.exhale + u.hold2;
    if (cycleDur < 0.1) cycleDur = 12.0;  // safety fallback
    float t = fmod(u.time, cycleDur);

    float progress;  // 0 = contracted (center), 1 = expanded (max)
    float glow;      // brightness multiplier

    float inhaleEnd = u.inhale;
    float holdEnd   = inhaleEnd + u.hold;
    float exhaleEnd = holdEnd + u.exhale;

    if (t < inhaleEnd) {
        // Inhale: expand with smooth sine easing
        float p = t / max(u.inhale, 0.01);
        progress = 0.5 - 0.5 * cos(p * 3.14159);  // sine ease 0→1
        glow = 0.3 + 0.7 * progress;               // brightens
    } else if (t < holdEnd) {
        // Hold: stay expanded, gentle soft flash (~1Hz) for counting
        progress = 1.0;
        float holdT = t - inhaleEnd;
        float pulse = 0.7 + 0.3 * sin(holdT * 2.0 * 3.14159);  // soft 1Hz oscillation
        glow = pulse;
    } else if (t < exhaleEnd) {
        // Exhale: contract with smooth sine easing
        float p = (t - holdEnd) / max(u.exhale, 0.01);
        progress = 0.5 + 0.5 * cos(p * 3.14159);  // sine ease 1→0
        glow = 0.3 + 0.7 * progress;               // dims
    } else {
        // Hold2: stay contracted, gentle soft flash for counting
        progress = 0.0;
        float hold2T = t - exhaleEnd;
        float pulse = 0.2 + 0.15 * sin(hold2T * 2.0 * 3.14159);  // dimmer pulse
        glow = pulse;
    }

    // Ring position: 8px (contracted) to maxRadius (expanded)
    float ringPos = 8.0 + progress * (u.maxRadius - 8.0);

    // Razor-thin gaussian ring — sigma 1.2px
    float ringDist = abs(dist - ringPos);
    float sigma = 1.2;
    float ring = exp(-ringDist * ringDist / (sigma * sigma * 2.0));

    // Dotted pattern: 60 dots around circumference
    float angle = atan2(delta.y, delta.x);
    float dotCount = 60.0;
    float dotPattern = step(0.45, fract(angle * dotCount / (2.0 * 3.14159)));

    // When contracted to center, use solid tiny ring (not dotted — too small for dots)
    float isTiny = smoothstep(20.0, 8.0, ringPos);
    dotPattern = mix(dotPattern, 1.0, isTiny);

    float a = ring * dotPattern * 0.08 * glow * u.fadeIn;
    if (a < 0.001) discard_fragment();
    return float4(u.color.rgb, a);
}

// ═══════════════════════════════════════════
//  Brightness cap — luminance clamp post-process
//  Uses [[color(0)]] programmable blending to read
//  the current framebuffer in-place.
// ═══════════════════════════════════════════

fragment float4 brightnessCapFragment(QuadVertex in [[stage_in]],
                                       float4 dest [[color(0)]],
                                       constant float &cap [[buffer(0)]]) {
    float3 rgb = dest.rgb;

    // RGB → HSL (find luminance via max/min)
    float cMax = max(rgb.r, max(rgb.g, rgb.b));
    float cMin = min(rgb.r, min(rgb.g, rgb.b));
    float L = (cMax + cMin) * 0.5;

    float maxL = cap;  // cap * 1.0
    if (L <= maxL || cMax < 0.001) {
        return dest;   // already under cap or black
    }

    // Clamp luminance: scale RGB so new luminance = maxL
    // For simplicity: scale = maxL / L, applied to RGB
    float scale = maxL / max(L, 0.001);
    float3 clamped = rgb * scale;
    return float4(clamped, dest.a);
}

// ═══════════════════════════════════════════
//  Radial vignette (darker edges)
// ═══════════════════════════════════════════

struct VignetteUniforms {
    float2 canvasSize;
};

fragment float4 radialVignetteFragment(QuadVertex in [[stage_in]],
                                       constant VignetteUniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    // Distance from center in UV space (0 at center, ~1.4 at corners)
    float dist = length((uv - 0.5) * 2.0);
    // Darken edges by up to 12%
    float darken = smoothstep(0.4, 1.4, dist) * 0.12;
    if (darken < 0.002) discard_fragment();
    return float4(0.0, 0.0, 0.0, darken);
}
