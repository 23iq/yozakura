#version 440
// The panorama wallpaper image (PanoramaLayer.qml).
//   mode 0: the image as is
//   mode 1: parallax: the image split into depth layers (far / mid / near,
//           from `depthMap`), the nearer layers displaced by up to `shift`
//           (uv units) without duplicating them: each pixel looks for the
//           nearest layer that lands on it, the strip a near layer uncovers
//           repeats the background beside it
//   mode 2: only the near layer (desktop depth layering), soft edged
// The depth comes from a grey map (.r, white = near) or, with alphaDepth, a
// subject cut-out's alpha. Optionally tints the colours to the shell
// palette (same Gaussian mapping as wallpapers/palette.frag).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D depthMap;
layout(binding = 3) uniform sampler2D paletteTexture;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float mode;
    float shift;
    float alphaDepth;
    float midDepth;
    float nearDepth;
    float edge;
    float midLead;
    float paletteSize;
    float tintEnabled;
    float texel;
    float texelY;
} ubuf;

float rawDepth(vec2 uv) {
    vec4 d = texture(depthMap, clamp(uv, vec2(0.0), vec2(1.0)));
    return ubuf.alphaDepth > 0.5 ? d.a : d.r;
}

// Depth grown by a few texels: anti-aliased colour edges of a near layer
// count as near, so the background never shows its rim.
float grownDepth(vec2 uv) {
    vec2 t = vec2(ubuf.texel * 3.0, 0.0);
    vec2 v = vec2(0.0, ubuf.texelY * 3.0);
    float d = max(rawDepth(uv), max(rawDepth(uv - t), rawDepth(uv + t)));
    return max(d, max(rawDepth(uv - v), rawDepth(uv + v)));
}

// Layer of a depth value: 0 far, midLead mid, 1 near.
float level(float d) {
    float mid = smoothstep(ubuf.midDepth, ubuf.midDepth + ubuf.edge, d);
    float near = smoothstep(ubuf.nearDepth, ubuf.nearDepth + ubuf.edge, d);
    return mix(mid * ubuf.midLead, 1.0, near);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float alpha = 1.0;

    if (ubuf.mode > 1.5) {
        alpha = smoothstep(ubuf.nearDepth, ubuf.nearDepth + ubuf.edge, rawDepth(uv));
    } else if (ubuf.mode > 0.5 && abs(ubuf.shift) > 0.0) {
        vec2 s = vec2(ubuf.shift, 0.0);
        float levels[3] = float[3](1.0, ubuf.midLead, 0.0);
        bool found = false;
        vec2 pick = uv;
        for (int i = 0; i < 3; i++) {
            float lv = levels[i];
            float d = lv > 0.99 ? rawDepth(uv - s * lv) : grownDepth(uv - s * lv);
            if (abs(level(d) - lv) < 0.25) {
                pick = uv - s * lv;
                found = true;
                break;
            }
        }
        // Uncovered strip (a near layer moved off it): repeat the nearest
        // background on the side the layer moved away from.
        if (!found) {
            // One step past the first clear probe skips the soft edge.
            pick = uv - s * 1.5;
            for (int k = 1; k <= 12; k++) {
                vec2 probe = uv - s * (0.125 * float(k));
                if (level(grownDepth(probe)) < 0.1) {
                    pick = probe - s * 0.125;
                    break;
                }
            }
        }
        uv = pick;
    }

    vec4 tex = texture(source, clamp(uv, vec2(0.0), vec2(1.0)));
    // Qt Quick textures are premultiplied.
    vec3 color = tex.a > 0.0001 ? tex.rgb / tex.a : vec3(0.0);
    alpha *= tex.a;

    if (ubuf.tintEnabled > 0.5) {
        vec3 acc = vec3(0.0);
        float total = 0.0;
        int size = int(ubuf.paletteSize);
        for (int i = 0; i < 128; i++) {
            if (i >= size)
                break;
            vec3 p = texture(paletteTexture, vec2((float(i) + 0.5) / ubuf.paletteSize, 0.5)).rgb;
            vec3 d = color - p;
            float w = exp(-20.0 * dot(d, d));
            acc += p * w;
            total += w;
        }
        color = acc / (total + 0.00001);
    }

    fragColor = vec4(color * alpha, alpha) * ubuf.qt_Opacity;
}
