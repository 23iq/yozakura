#version 440
// Wallpaper transition: blends the outgoing wallpaper (fromSource) into the
// incoming one (toSource). Only mounted while a transition runs.
//
// mode: 0 = fade, 1 = grow (circle from origin), 2 = wipe (angled, soft,
//       slightly organic edge), 3 = dissolve (noise with soft edge)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;  // 0..1, already eased
    float mode;
    float aspect;    // width / height
    vec2 origin;     // grow origin, normalized item coords
    float angle;     // wipe direction, radians
    float seed;      // per-transition noise offset
} ubuf;

layout(binding = 1) uniform sampler2D fromSource;
layout(binding = 2) uniform sampler2D toSource;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * valueNoise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        amp *= 0.5;
    }
    return v;
}

// Zoom around the centre: s > 1 magnifies.
vec2 zoom(vec2 uv, float s) {
    return (uv - 0.5) / s + 0.5;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);
    int mode = int(ubuf.mode + 0.5);

    // Subtle parallax: the outgoing image drifts back, the incoming one
    // settles from a slight zoom. Disabled for plain fade.
    float settle = (mode == 0) ? 0.0 : 1.0;
    vec4 fromColor = texture(fromSource, zoom(uv, 1.0 + 0.02 * p * settle));
    vec4 toColor = texture(toSource, zoom(uv, 1.0 + 0.035 * (1.0 - p) * settle));

    // Aspect-corrected coordinates so circles stay round.
    vec2 st = vec2(uv.x * ubuf.aspect, uv.y);

    float mask; // 0 = from, 1 = to
    if (mode == 1) {
        vec2 o = vec2(ubuf.origin.x * ubuf.aspect, ubuf.origin.y);
        // Farthest corner decides the radius needed to cover the screen.
        float maxDist = 0.0;
        maxDist = max(maxDist, distance(o, vec2(0.0, 0.0)));
        maxDist = max(maxDist, distance(o, vec2(ubuf.aspect, 0.0)));
        maxDist = max(maxDist, distance(o, vec2(0.0, 1.0)));
        maxDist = max(maxDist, distance(o, vec2(ubuf.aspect, 1.0)));
        float feather = 0.08;
        float d = distance(st, o);
        // Gentle wobble on the rim so it doesn't look like a hard stencil.
        float ang = atan(st.y - o.y, st.x - o.x);
        d += 0.012 * (valueNoise(vec2(ang * 3.0 + ubuf.seed, p * 2.0)) - 0.5);
        float radius = p * (maxDist + feather);
        mask = 1.0 - smoothstep(radius - feather, radius, d);
    } else if (mode == 2) {
        vec2 dir = vec2(cos(ubuf.angle), sin(ubuf.angle));
        // Project the four corners to normalise the sweep to [0, 1].
        float c0 = dot(vec2(0.0, 0.0), dir);
        float c1 = dot(vec2(ubuf.aspect, 0.0), dir);
        float c2 = dot(vec2(0.0, 1.0), dir);
        float c3 = dot(vec2(ubuf.aspect, 1.0), dir);
        float lo = min(min(c0, c1), min(c2, c3));
        float hi = max(max(c0, c1), max(c2, c3));
        float pos = (dot(st, dir) - lo) / (hi - lo);
        // Organic edge: displace along the sweep with low-frequency noise.
        vec2 perp = vec2(-dir.y, dir.x);
        pos += 0.035 * (fbm(vec2(dot(st, perp) * 3.0 + ubuf.seed, p * 1.5)) - 0.5);
        float soft = 0.12;
        float edge = p * (1.0 + 2.0 * soft) - soft;
        mask = 1.0 - smoothstep(edge - soft, edge + soft, pos);
    } else if (mode == 3) {
        // Domain-warped fbm: organic, ink-like blobs without grid artefacts.
        vec2 q = st * 3.2 + vec2(ubuf.seed, ubuf.seed * 0.7);
        vec2 warp = vec2(fbm(q + vec2(1.7, 9.2)), fbm(q + vec2(8.3, 2.8)));
        float n = fbm(q + 1.6 * warp);
        // fbm clusters around 0.5; stretch it so the dissolve spreads
        // evenly over the whole duration.
        n = clamp((n - 0.25) / 0.5, 0.0, 1.0);
        float soft = 0.06;
        float edge = p * (1.0 + 2.0 * soft) - soft;
        mask = 1.0 - smoothstep(edge - soft, edge + soft, n);
    } else {
        mask = p;
    }

    fragColor = mix(fromColor, toColor, mask) * ubuf.qt_Opacity;
}
