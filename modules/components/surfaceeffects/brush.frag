#version 440
// Sumi-e brush stroke filling the item (BrushStroke.qml): pressed head,
// wobbling body with irregular edges, tapered dry-brush tail. The stroke
// runs along the item's long axis. Output is premultiplied.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in px
    vec4 inkColor;    // ink color (straight alpha)
    float seed;       // stroke variation
    float roughness;  // 0..1 edge irregularity
    float dryness;    // 0..1 dry-brush streaks in the tail
    float reveal;     // 0..1 drawn length (stroke animation)
} ubuf;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise1(float x) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash1(i), hash1(i + 1.0), f);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    bool vertical = ubuf.size.y > ubuf.size.x;
    float len = vertical ? ubuf.size.y : ubuf.size.x;
    float thick = vertical ? ubuf.size.x : ubuf.size.y;
    float along = vertical ? px.y : px.x;
    float across = (vertical ? px.x : px.y) - thick * 0.5;
    float u = along / max(len, 1.0);
    float s = ubuf.seed;
    float half_t = thick * 0.5;

    // Body: slight belly, center wobble, irregular top and bottom edges.
    float wob = (noise1(u * 2.5 + s) * 2.0 - 1.0) * thick * 0.05 * ubuf.roughness;
    float c = across - wob;
    float ragTop = noise1(along * 0.28 + s * 7.0) * 0.6 + noise1(along * 0.9 + s * 3.0) * 0.4;
    float ragBot = noise1(along * 0.28 + s * 13.0 + 50.0) * 0.6 + noise1(along * 0.9 + s * 5.0 + 20.0) * 0.4;
    float rag = c < 0.0 ? ragTop : ragBot;
    float prof = half_t * (0.86 + 0.06 * sin(u * 3.14159)) * (1.0 - ubuf.roughness * 0.16 * rag);

    // Caps: rounded pressed head, long tapered tail.
    float head = clamp(along / (half_t * 1.1), 0.0, 1.0);
    float tail = clamp((len - along) / (thick * 1.1), 0.0, 1.0);
    prof *= sqrt(head) * mix(0.35, 1.0, sqrt(tail));
    prof *= 1.0 - smoothstep(0.82, 1.0, u) * (1.0 - tail) * 0.4;

    float d = abs(c) - prof;

    // Short marks (pills, square slots): a ragged dab instead, a capsule
    // whose radius wobbles around its outline.
    float aspect = len / max(thick, 1.0);
    if (aspect < 1.6) {
        float reach = max(len * 0.5 - half_t, 0.0);
        vec2 off = vec2(max(abs(along - len * 0.5) - reach, 0.0), across);
        float ang = atan(off.y, off.x + 0.001 * sign(along - len * 0.5));
        float ragD = noise1(ang * 1.6 + along * 0.08 + s * 5.0) * 0.65 + noise1(ang * 4.5 + s * 11.0) * 0.35;
        float dab = length(off) - half_t * 0.9 * (1.0 - ubuf.roughness * 0.16 * ragD);
        d = mix(dab, d, smoothstep(1.15, 1.6, aspect));
    }
    float aa = 0.8;
    float alpha = 1.0 - smoothstep(-aa, aa, d);

    // Dry brush: streaks open up toward the tail and along the edges.
    float streak = noise2(vec2(along * 0.025 + s, c * 0.85));
    float edgeness = clamp(abs(c) / max(prof, 0.5), 0.0, 1.0);
    float thr = ubuf.dryness * (smoothstep(0.55, 1.0, u) * 0.75 + smoothstep(0.75, 1.0, edgeness) * 0.25);
    thr *= smoothstep(1.3, 2.6, aspect);
    alpha *= smoothstep(thr - 0.08, thr + 0.08, streak);

    // Ink density: barely varying, never below legible.
    alpha *= 0.9 + 0.1 * noise2(px * 0.12 + vec2(s));

    // Stroke drawing in (reveal along the stroke).
    alpha *= 1.0 - smoothstep(ubuf.reveal * 1.08 - 0.08, ubuf.reveal * 1.08, u);

    float a = ubuf.inkColor.a * alpha;
    fragColor = vec4(ubuf.inkColor.rgb * a, a) * ubuf.qt_Opacity;
}
