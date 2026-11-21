#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float bass;
    float aspect;
    vec2 mouse;
    vec4 base;
    vec4 colA;
    vec4 colB;
} ubuf;
// Ashura "drift": slow clouds in the palette's colours; the bass swells them and
// the mouse stirs the field around it.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int k = 0; k < 5; k++) { v += a * noise(p); p *= 2.0; a *= 0.5; }
    return v;
}
void main() {
    vec2 uv = qt_TexCoord0 * vec2(ubuf.aspect, 1.0);
    float t = ubuf.time * 0.04;
    vec2 p = uv * 2.2 + vec2(t, -t * 0.6);
    if (ubuf.mouse.x >= 0.0) {
        vec2 m = ubuf.mouse * vec2(ubuf.aspect, 1.0);
        vec2 d = uv - m;
        p += normalize(d + 1e-4) * 0.25 * exp(-dot(d, d) * 6.0);
    }
    float n = fbm(p + fbm(p + t));
    vec3 col = ubuf.base.rgb;
    col = mix(col, ubuf.colB.rgb, smoothstep(0.45, 0.85, n) * (0.35 + 0.35 * ubuf.bass));
    col = mix(col, ubuf.colA.rgb, smoothstep(0.62, 0.95, n) * (0.30 + 0.50 * ubuf.bass));
    vec2 v = qt_TexCoord0 - 0.5;
    col *= 1.0 - 0.35 * dot(v, v);
    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
