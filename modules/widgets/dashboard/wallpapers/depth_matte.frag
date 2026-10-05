#version 440
// Stacked-alpha "matte video" (scripts/depth_video.py): the stream holds the
// colour frame on top and its foreground mask (luma) below, each half padded
// to whole macroblocks. Draws either the wallpaper (top half) or the subject
// cutout (top half, alpha from the bottom half) with PreserveAspectCrop
// framing and the optional palette tint of palette.frag.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D paletteTexture;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 cropOffset;   // visible window into the content, 0..1
    vec2 cropScale;
    float contentFrac; // content rows / padded rows of one half
    float texelY;      // 1 / texture height
    float foreground;  // 0: wallpaper, 1: subject cutout
    float tint;        // 1: snap colours to the palette
    float paletteSize;
} ubuf;

vec3 tinted(vec3 color) {
    vec3 acc = vec3(0.0);
    float total = 0.0;
    int size = int(ubuf.paletteSize);
    for (int i = 0; i < 128; i++) {
        if (i >= size) break;
        vec3 p = texture(paletteTexture, vec2((float(i) + 0.5) / ubuf.paletteSize, 0.5)).rgb;
        vec3 d = color - p;
        float w = exp(-20.0 * dot(d, d));
        acc += p * w;
        total += w;
    }
    return acc / (total + 0.00001);
}

void main() {
    vec2 uv = ubuf.cropOffset + qt_TexCoord0 * ubuf.cropScale;
    float half_ = 0.5 * ubuf.contentFrac;
    // Keep bilinear taps inside their own half.
    float cy = clamp(uv.y * half_, ubuf.texelY, half_ - ubuf.texelY);
    vec3 color = texture(source, vec2(uv.x, cy)).rgb;
    if (ubuf.tint > 0.5)
        color = tinted(color);

    float a = 1.0;
    if (ubuf.foreground > 0.5) {
        float my = clamp(0.5 + uv.y * half_, 0.5 + ubuf.texelY, 0.5 + half_ - ubuf.texelY);
        // Video-range rounding leaves a little noise around 0 and 1.
        a = clamp((texture(source, vec2(uv.x, my)).g - 0.03) / 0.94, 0.0, 1.0);
    }
    fragColor = vec4(color * a, a) * ubuf.qt_Opacity;
}
