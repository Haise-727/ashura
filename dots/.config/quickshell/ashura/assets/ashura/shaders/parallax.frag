// Compiled to parallax.vN.frag.qsb: Qt caches shaders by file name, so bump N
// on every change or a running shell keeps the old one.
//
// Ashura: depth parallax for the wallpaper (modules/ashura/wallpaperFx/
// CharacterParallax.qml, data from scripts/ashura/depthlayers).
//
// mode 1, layers: three layers (back, middle, front), each completed behind
// the nearer ones, drawn back to front; every pixel moves by its own depth
// (near with the pointer, far against it), so no layer is a flat cut-out.
// mode 0, fallback: the original picture warped by its depth map alone.
// Both resolve the warp with two fixed-point steps (the shift depends on the
// depth at the shifted place).
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float offx;       // shift for a pixel at depth 1 relative to `stillDepth`, texture units
    float offy;
    float stillDepth; // the depth that stays still
    float mode;       // 1 layers, 0 depth warp
};
layout(binding = 1) uniform sampler2D src;
layout(binding = 2) uniform sampler2D dispTex;
layout(binding = 3) uniform sampler2D l0;
layout(binding = 4) uniform sampler2D l1;
layout(binding = 5) uniform sampler2D l2;
layout(binding = 6) uniform sampler2D d0;
layout(binding = 7) uniform sampler2D d1;
layout(binding = 8) uniform sampler2D d2;

vec2 warp(sampler2D dep, vec2 uv) {
    vec2 off = vec2(offx, offy);
    vec2 u = uv - off * (texture(dep, uv).r - stillDepth);
    u = uv - off * (texture(dep, clamp(u, 0.0, 1.0)).r - stillDepth);
    return clamp(u, 0.0, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c;
    if (mode > 0.5) {
        c = texture(l0, warp(d0, uv));
        vec4 m = texture(l1, warp(d1, uv));
        c = m + c * (1.0 - m.a);                    // premultiplied "over"
        vec4 f = texture(l2, warp(d2, uv));
        c = f + c * (1.0 - f.a);
        c.a = 1.0;
    } else {
        c = vec4(texture(src, warp(dispTex, uv)).rgb, 1.0);
    }
    fragColor = c * qt_Opacity;
}
