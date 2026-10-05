#version 440
// Depth-clock subject cutout: sharpens the soft matte edge at render time
// (cached masks stay valid when the thresholds change) and optionally tints
// the colours to the shell palette like the tinted wallpaper does.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D paletteTexture;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float paletteSize;
    float tintEnabled;
    float edgeLow;
    float edgeHigh;
} ubuf;

void main() {
    vec4 tex = texture(source, qt_TexCoord0);
    // Qt Quick textures are premultiplied.
    vec3 color = tex.a > 0.0001 ? tex.rgb / tex.a : vec3(0.0);
    float alpha = smoothstep(ubuf.edgeLow, ubuf.edgeHigh, tex.a);

    if (ubuf.tintEnabled > 0.5) {
        // Same Gaussian palette mapping as wallpapers/palette.frag.
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
