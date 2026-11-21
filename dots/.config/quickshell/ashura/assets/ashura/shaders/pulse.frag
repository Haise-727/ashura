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
// Ashura "pulse": soft rings spreading from a centre that follows the mouse
// (screen centre when the mouse is over a window), beating with the bass.
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 c = ubuf.mouse.x >= 0.0 ? ubuf.mouse : vec2(0.5, 0.5);
    vec2 d = (uv - c) * vec2(ubuf.aspect, 1.0);
    float r = length(d);
    float rings = 0.5 + 0.5 * sin(r * 26.0 - ubuf.time * (1.2 + 2.5 * ubuf.bass));
    rings = pow(rings, 6.0) * exp(-r * (2.2 - ubuf.bass));
    vec3 col = ubuf.base.rgb;
    col = mix(col, mix(ubuf.colA.rgb, ubuf.colB.rgb, smoothstep(0.0, 0.8, r)), rings * (0.45 + 0.55 * ubuf.bass));
    vec2 v = uv - 0.5;
    col *= 1.0 - 0.35 * dot(v, v);
    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
