#version 440
// Ashura "aurora": slow bands of light in the palette's colours. Bass (from cava)
// brightens and lifts the bands; the mouse lights a soft glow where it is.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float bass;      // 0..1
    float aspect;    // width / height
    vec2 mouse;      // 0..1, (-1,-1) when off the desktop
    vec4 base;       // surface
    vec4 colA;       // primary
    vec4 colB;       // tertiary
} ubuf;

float band(vec2 uv, float speed, float freq, float offset) {
    float y = 0.5 + 0.18 * sin(uv.x * freq + ubuf.time * speed + offset)
                  + 0.06 * sin(uv.x * freq * 2.3 - ubuf.time * speed * 1.7 + offset);
    float width = 0.10 + 0.08 * ubuf.bass;
    return smoothstep(width, 0.0, abs(uv.y - y));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 col = ubuf.base.rgb;
    float a = band(uv, 0.15, 3.0, 0.0);
    float b = band(uv + vec2(0.0, 0.12), 0.11, 2.2, 2.0);
    col = mix(col, ubuf.colA.rgb, a * (0.55 + 0.45 * ubuf.bass));
    col = mix(col, ubuf.colB.rgb, b * (0.40 + 0.40 * ubuf.bass));
    if (ubuf.mouse.x >= 0.0) {
        vec2 d = (uv - ubuf.mouse) * vec2(ubuf.aspect, 1.0);
        col += ubuf.colA.rgb * 0.35 * exp(-dot(d, d) * 18.0);
    }
    // gentle vignette so text on the desktop stays readable
    vec2 v = uv - 0.5;
    col *= 1.0 - 0.35 * dot(v, v);
    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
