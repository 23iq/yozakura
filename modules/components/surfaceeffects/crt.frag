#version 440
// CRT surface overlay (CrtSurface.qml): static scanlines aligned to screen
// rows, an edge vignette and a soft phosphor bloom in the accent color.
// Output is premultiplied; no time input (static unless `flash` animates).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in px
    vec4 rowMap;      // screen row of local (x, y): x*rowMap.x + y*rowMap.y + rowMap.z
    vec4 glow;        // phosphor color (straight alpha)
    float strength;   // 0..1, legibility-clamped
    float pitch;      // scanline period in px
    float flash;      // 0..1 power-on flicker
    float lift;       // lit-row phosphor (1 on dark surfaces, lower on light)
    vec4 radii;       // corner radii tl, tr, br, bl (rounded clip)
} ubuf;

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
    float s = ubuf.strength;

    // Scanlines: a soft dark band once per `pitch` screen rows.
    float row = px.x * ubuf.rowMap.x + px.y * ubuf.rowMap.y + ubuf.rowMap.z;
    float ph = fract(row / ubuf.pitch);
    float band = smoothstep(0.50, 0.70, ph) * (1.0 - smoothstep(0.88, 1.0, ph));
    float scan = band * 0.20 * s;

    // Vignette: darker toward the edges (tube curvature), bounded.
    float edge = min(min(px.x, ubuf.size.x - px.x), min(px.y, ubuf.size.y - px.y));
    float reach = clamp(min(ubuf.size.x, ubuf.size.y) * 0.5, 4.0, 48.0);
    vec2 q = qt_TexCoord0 * 2.0 - 1.0;
    float vig = max((1.0 - smoothstep(0.0, reach, edge)) * 0.14, smoothstep(0.6, 1.42, length(q)) * 0.10) * s;

    float dark = 1.0 - (1.0 - scan) * (1.0 - vig);

    // Phosphor: lit rows between the dark bands and a soft bloom from the
    // middle, in the accent color (+ the open flicker).
    float rows = (1.0 - band) * 0.05 * s * ubuf.lift;
    float bloom = ((1.0 - smoothstep(0.0, 1.0, length(q))) * 0.10 * s + rows) * ubuf.glow.a + ubuf.flash * 0.10;

    float a = bloom + dark * (1.0 - bloom);
    fragColor = roundedCoverage(px, ubuf.size, ubuf.radii) * vec4(ubuf.glow.rgb * bloom, a) * ubuf.qt_Opacity;
}
