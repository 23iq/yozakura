#version 440
// Heat shimmer (HeatShimmer.qml): thin wavering bright ripples rising
// through the bar, like air over hot asphalt. `amp` fades a wave in and out;
// `phase` moves it (both animated only while a wave passes). Output is
// premultiplied.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;   // seconds of the wave
    float amp;     // 0..1 wave envelope
    float aspect;  // width / height
    vec4 tint;     // ripple colour (straight alpha = peak alpha)
} ubuf;

void main() {
    vec2 uv = qt_TexCoord0;
    float t = ubuf.phase;
    float x = uv.x * ubuf.aspect;
    // Wavering iso-lines that drift upward
    float wob = sin(x * 2.3 + t * 1.6) * 0.6 + sin(x * 5.1 - t * 2.4) * 0.35;
    float v = sin((uv.y + t * 0.32) * 7.0 + wob * 2.2 + sin(x * 0.7 + t) * 1.5);
    float line = pow(smoothstep(0.3, 1.0, v), 2.0);
    // Breaks along the ripple so it reads as shimmer, not stripes
    float gaps = smoothstep(-0.2, 0.7, sin(x * 1.7 - t * 0.9 + uv.y * 3.0));
    // Brighter low in the bar, gone at the very top
    float fade = smoothstep(0.0, 0.6, uv.y);
    // A wave sweeps across the bar
    float sweep = smoothstep(0.0, 0.5, sin(uv.x * 3.14159 * 0.9 + t * 0.55) * 0.5 + 0.5);
    float a = ubuf.tint.a * ubuf.amp * line * gaps * fade * (0.45 + 0.55 * sweep);
    fragColor = vec4(ubuf.tint.rgb * a, a) * ubuf.qt_Opacity;
}
