#version 440
// Analytic drop shadow (ShapeShadow.qml): no texture, no offscreen pass,
// one quad whose cost does not depend on how often the shape moves or
// resizes. The shape is a box with per-corner radii, plus optional concave
// fillets where it meets a screen edge (the attached notch), or everything
// outside that box (the screen frame around its hole).
//
// The blur is MultiEffect's, modelled as the sharp shape plus Gaussians of
// sigma 2, 4, 8 and 16 px (weights from ShadowBlur.js). A Gaussian blur of
// a shape whose rows are single intervals is integrated exactly along each
// row (erf) and numerically across rows (ROWS slices, each weighted by its
// exact Gaussian mass), so rounded corners and fillets stay accurate.
// Compile: qsb --qt6 -o shape_shadow.frag.qsb shape_shadow.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // item size (px)
    vec4 shapeBox;      // shape box in item px: x, y, w, h
    vec4 radii;         // tl, tr, br, bl
    vec4 weights;       // Gaussian weights of sigma 2, 4, 8, 16
    float sharpWeight;  // weight of the unblurred shape
    float filletSize;   // concave edge fillet size (px), 0 = none
    float edgeIndex;    // edge the fillets sit on: 0 top, 1 bottom, 2 left, 3 right
    float invertedFlag; // 1 = shadow of everything outside the box
    vec4 color;         // premultiplied shadow colour
} ubuf;

const int ROWS = 8;
const vec4 SIGMAS = vec4(2.0, 4.0, 8.0, 16.0);

// Gaussian CDF; erf from Abramowitz & Stegun 7.1.26 (|error| < 1.5e-7)
float gcdf(float x, float s) {
    float z = x / (s * 1.41421356);
    float a = abs(z);
    float t = 1.0 / (1.0 + 0.3275911 * a);
    float e = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-a * a);
    return 0.5 + 0.5 * sign(z) * e;
}

// Signed distance to a rounded box (positive outside); c centre, b half size
float roundBox(vec2 p, vec2 c, vec2 b, vec4 r) {
    vec2 q = p - c;
    float rr = q.y < 0.0 ? (q.x < 0.0 ? r.x : r.y) : (q.x < 0.0 ? r.w : r.z);
    rr = min(rr, min(b.x, b.y));
    vec2 d = abs(q) - b + rr;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - rr;
}

// Horizontal inset of a corner arc of radius r, k px into its band
float arcInset(float r, float k) {
    k = clamp(k, 0.0, r);
    return r - sqrt(max(r * r - k * k, 0.0));
}

// Gaussian blur (sigma s) of the rounded box o, size z, at p
float boxBlur(vec2 p, vec2 o, vec2 z, vec4 r, float s) {
    float h = min(z.x, z.y) * 0.5;
    r = min(r, vec4(h));
    float y0 = o.y;
    float y1 = o.y + z.y;
    float a = clamp(p.y - 3.0 * s, y0, y1);
    float b = clamp(p.y + 3.0 * s, y0, y1);
    if (b <= a)
        return 0.0;
    float dy = (b - a) / float(ROWS);
    float prev = gcdf(a - p.y, s);
    float sum = 0.0;
    for (int i = 0; i < ROWS; i++) {
        float yb = a + dy * float(i + 1);
        float cur = gcdf(yb - p.y, s);
        float ym = a + dy * (float(i) + 0.5);
        float il = max(arcInset(r.x, y0 + r.x - ym), arcInset(r.w, ym - (y1 - r.w)));
        float ir = max(arcInset(r.y, y0 + r.y - ym), arcInset(r.z, ym - (y1 - r.z)));
        float row = gcdf(o.x + z.x - ir - p.x, s) - gcdf(o.x + il - p.x, s);
        sum += (cur - prev) * row;
        prev = cur;
    }
    return sum;
}

// Gaussian blur of one concave fillet in edge space (u along the edge, v
// away from it): the square [u0, u0 + f] x [0, f] without the quarter disk
// centred on its far corner; `left` = the disk sits at u0 (else u0 + f).
float filletBlur(vec2 uv, float u0, float f, bool left, float s) {
    float a = clamp(uv.y - 3.0 * s, 0.0, f);
    float b = clamp(uv.y + 3.0 * s, 0.0, f);
    if (b <= a)
        return 0.0;
    float dy = (b - a) / float(ROWS);
    float prev = gcdf(a - uv.y, s);
    float sum = 0.0;
    for (int i = 0; i < ROWS; i++) {
        float vb = a + dy * float(i + 1);
        float cur = gcdf(vb - uv.y, s);
        float vm = a + dy * (float(i) + 0.5);
        // disk centre at depth f: it covers |du| < sqrt(f^2 - (f - v)^2)
        float reach = sqrt(max(f * f - (f - vm) * (f - vm), 0.0));
        float ua = left ? u0 + reach : u0;
        float ub = left ? u0 + f : u0 + f - reach;
        float row = ub > ua ? gcdf(ub - uv.x, s) - gcdf(ua - uv.x, s) : 0.0;
        sum += (cur - prev) * row;
        prev = cur;
    }
    return sum;
}

float sharpFillet(vec2 uv, float u0, float f, bool left) {
    vec2 c = vec2(left ? u0 : u0 + f, f);
    bool inSquare = uv.x >= u0 && uv.x <= u0 + f && uv.y >= 0.0 && uv.y <= f;
    return inSquare && length(uv - c) >= f ? 1.0 : 0.0;
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.itemSize;
    vec2 o = ubuf.shapeBox.xy;
    vec2 z = ubuf.shapeBox.zw;
    float f = ubuf.invertedFlag > 0.5 ? 0.0 : ubuf.filletSize;
    vec4 w = ubuf.weights;
    float reach = w.w > 0.0 ? 48.0 : w.z > 0.0 ? 24.0 : w.y > 0.0 ? 12.0 : 6.0;

    // body: the box without the fillets along the edge
    bool alongX = ubuf.edgeIndex < 1.5;
    vec2 bo = o;
    vec2 bz = z;
    if (f > 0.0) {
        bo = alongX ? vec2(o.x + f, o.y) : vec2(o.x, o.y + f);
        bz = alongX ? vec2(z.x - f * 2.0, z.y) : vec2(z.x, z.y - f * 2.0);
    }
    bz = max(bz, vec2(0.0));
    float body = roundBox(p, bo + bz * 0.5, bz * 0.5, ubuf.radii);
    // the fillets lie inside the box: its distance bounds them
    float d = f > 0.0 ? min(body, max(max(o.x - p.x, p.x - o.x - z.x), max(o.y - p.y, p.y - o.y - z.y))) : body;

    // far from the shape: nothing (inside the frame's hole: no shadow)
    if (ubuf.invertedFlag > 0.5 ? d < -reach - 1.0 : d > reach + 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    // deep under the frame (outside its hole): full shadow, no blur sums;
    // only the band within the blur's reach of the hole edge pays for them
    if (ubuf.invertedFlag > 0.5 && d > reach + 1.0) {
        fragColor = ubuf.color * ubuf.qt_Opacity;
        return;
    }

    float cover = ubuf.sharpWeight * clamp(0.5 - body, 0.0, 1.0);
    for (int i = 0; i < 4; i++) {
        if (w[i] > 0.0)
            cover += w[i] * boxBlur(p, bo, bz, ubuf.radii, SIGMAS[i]);
    }

    if (f > 0.0) {
        // edge space: u along the edge from the box start, v depth from it
        vec2 l = p - o;
        vec2 uv;
        float len;
        if (ubuf.edgeIndex < 0.5) {
            uv = l;
            len = z.x;
        } else if (ubuf.edgeIndex < 1.5) {
            uv = vec2(l.x, z.y - l.y);
            len = z.x;
        } else if (ubuf.edgeIndex < 2.5) {
            uv = vec2(l.y, l.x);
            len = z.y;
        } else {
            uv = vec2(l.y, z.x - l.x);
            len = z.y;
        }
        cover += ubuf.sharpWeight * (sharpFillet(uv, 0.0, f, true) + sharpFillet(uv, len - f, f, false));
        for (int i = 0; i < 4; i++) {
            if (w[i] > 0.0)
                cover += w[i] * (filletBlur(uv, 0.0, f, true, SIGMAS[i]) + filletBlur(uv, len - f, f, false, SIGMAS[i]));
        }
    }

    if (ubuf.invertedFlag > 0.5)
        cover = 1.0 - cover;
    fragColor = ubuf.color * clamp(cover, 0.0, 1.0) * ubuf.qt_Opacity;
}
