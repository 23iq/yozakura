#version 440
// Ink surface overlay (InkSurface.qml): static rice-paper grain (fine
// specks + horizontal fibers) and an irregular sumi wash at the edges, in
// the ink (text) color. Output is premultiplied.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in px
    vec4 ink;         // ink color (straight alpha)
    float strength;   // 0..1, legibility-clamped
    float grain;      // 0..1 paper grain amount
    float paper;      // 1 on light paper, lower on dark surfaces
    float seed;
    vec4 radii;       // corner radii tl, tr, br, bl (rounded clip)
} ubuf;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Coverage of the rounded host shape (its clip may be rectangular).
float roundedCoverage(vec2 px, vec2 size, vec4 r) {
    vec2 h = size * 0.5;
    vec2 p = px - h;
    float rad = p.x < 0.0 ? (p.y < 0.0 ? r.x : r.w) : (p.y < 0.0 ? r.y : r.z);
    rad = min(rad, min(h.x, h.y));
    vec2 q = abs(p) - h + vec2(rad);
    float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
    return clamp(0.5 - sd, 0.0, 1.0);
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 o = vec2(ubuf.seed * 17.0, ubuf.seed * 31.0);

    // Grain: sparse specks (1-2 px) and long horizontal paper fibers.
    float speck = smoothstep(0.70, 0.95, noise(px * 0.85 + o));
    float fiber = smoothstep(0.62, 0.98, noise(vec2(px.x * 0.045, px.y * 0.7) + o.yx));
    float tooth = noise(px * 0.33 + o) - 0.5;
    float grain = (speck * 0.09 + fiber * 0.06 + max(tooth, 0.0) * 0.05) * ubuf.grain * ubuf.paper;

    // Sumi wash: ink pooled unevenly along the edges.
    float edge = min(min(px.x, ubuf.size.x - px.x), min(px.y, ubuf.size.y - px.y));
    float reach = clamp(min(ubuf.size.x, ubuf.size.y) * 0.35, 3.0, 28.0);
    float ragged = 0.55 + 0.9 * noise(vec2(px.x + px.y, px.x - px.y) * 0.035 + o);
    float wash = (1.0 - smoothstep(0.0, reach * ragged, edge)) * 0.09;

    float a = clamp((grain + wash) * ubuf.strength * ubuf.ink.a, 0.0, 0.24);
    fragColor = roundedCoverage(px, ubuf.size, ubuf.radii) * vec4(ubuf.ink.rgb * a, a) * ubuf.qt_Opacity;
}
