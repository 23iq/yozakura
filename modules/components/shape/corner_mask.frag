#version 440
// Corner mask of a StyledRect (layer.effect): clips the rendered item to a
// squircle / cut / round shape with per-corner radii (0 = square corner),
// paints the fill under the content and the border over it. Signed distance
// in item units, antialiased over one screen pixel (fwidth), so edges stay
// crisp at any scale. Compile: qsb --qt6 -o corner_mask.frag.qsb corner_mask.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float shapeStyle;   // 0 round, 1 squircle, 2 cut
    float cutSize;
    float borderWidth;
    vec2 shapeSize;     // item size
    vec4 radii;         // tl, tr, br, bl
    vec4 fillColor;     // straight alpha
    vec4 borderColor;   // straight alpha
} ubuf;

layout(binding = 1) uniform sampler2D source;

const float SQUIRCLE_N = 4.0;
const float SQUIRCLE_REACH = 1.4;  // squircle curve spans 1.4x the radius

// Distance to the shape boundary, positive inside.
float shapeDistance(vec2 p) {
    vec2 s = ubuf.shapeSize;
    bool left = p.x < s.x * 0.5;
    bool top = p.y < s.y * 0.5;
    float r = top ? (left ? ubuf.radii.x : ubuf.radii.y) : (left ? ubuf.radii.w : ubuf.radii.z);
    // distances to the two edges meeting at the nearest corner
    vec2 q = vec2(left ? p.x : s.x - p.x, top ? p.y : s.y - p.y);
    float dEdge = min(q.x, q.y);
    float halfMin = 0.5 * min(s.x, s.y);
    if (r <= 0.0)
        return dEdge;

    if (ubuf.shapeStyle > 1.5) {
        float c = min(min(ubuf.cutSize, r), halfMin);
        return min(dEdge, (q.x + q.y - c) * 0.70710678);
    }
    if (ubuf.shapeStyle > 0.5) {
        float e = min(r * SQUIRCLE_REACH, halfMin);
        vec2 u = (e - q) / e;
        if (u.x <= 0.0 || u.y <= 0.0)
            return dEdge;
        vec2 u3 = u * u * u;
        float f = pow(u3.x * u.x + u3.y * u.y, 1.0 / SQUIRCLE_N);
        vec2 g = u3 / max(f * f * f, 1e-6);
        // first-order distance; never deeper than the straight edges (keeps
        // it continuous where the corner box meets them)
        return min((1.0 - f) * e / max(length(g), 1e-6), dEdge);
    }
    float rr = min(r, halfMin);
    vec2 v = rr - q;
    if (v.x <= 0.0 || v.y <= 0.0)
        return dEdge;
    return rr - length(v);
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.shapeSize;
    float d = shapeDistance(p);
    // one screen pixel in item units (not fwidth(d): the distance is only
    // first-order inside the squircle corner)
    float aa = max(max(fwidth(p.x), fwidth(p.y)), 1e-4);
    float inside = clamp(d / aa + 0.5, 0.0, 1.0);

    vec4 content = texture(source, qt_TexCoord0);
    vec4 fill = vec4(ubuf.fillColor.rgb * ubuf.fillColor.a, ubuf.fillColor.a);
    vec4 col = content + fill * (1.0 - content.a);

    if (ubuf.borderWidth > 0.0) {
        float inner = clamp((d - ubuf.borderWidth) / aa + 0.5, 0.0, 1.0);
        float b = (1.0 - inner) * ubuf.borderColor.a;
        col = col * (1.0 - b) + vec4(ubuf.borderColor.rgb, 1.0) * b;
    }
    fragColor = col * inside * ubuf.qt_Opacity;
}
