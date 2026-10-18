#version 440
// Slow silk ribbons drifting across a gradient, drawn per pixel so the CPU does
// no per-frame work. Every number that shapes the picture is a uniform set from
// the properties at the top of Waves.qml, where each one is explained.
//
// Build: qsb --qt6 -o waves.frag.qsb waves.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float swell;
    float aspect;
    vec4 backgroundTop;
    vec4 backgroundBottom;
    vec4 ribbonColor1;
    vec4 ribbonColor2;
    vec4 ribbonColor3;

    float ribbons;
    float firstRibbonHeight;
    float ribbonSpacing;
    float ribbonSpeedBase;
    float ribbonSpeedStep;
    float swayAmount;
    float swayFrequency;
    float swayFrequencyStep;
    float rippleAmount;
    float rippleFrequency;
    float rippleFrequencyStep;
    float ribbonWidthBase;
    float ribbonWidthVariation;
    float ribbonWidthFrequency;
    float fillStrength;
    float edgeStrength;
    float edgeSharpness;
    float gradientStrength;
    float gradientCurve;
};

const int MAX_RIBBONS = 8;

void main() {
    vec2 uv = qt_TexCoord0;
    float x = uv.x * aspect;

    // The background: from the top color to the bottom one, bent by gradientCurve.
    vec3 col = mix(backgroundTop.rgb, backgroundBottom.rgb, gradientStrength * pow(uv.y, gradientCurve));

    for (int i = 0; i < MAX_RIBBONS; i++) {
        float fi = float(i);
        if (fi >= ribbons) break;

        float t = time * (ribbonSpeedBase + ribbonSpeedStep * fi);
        // Where the ribbon's middle runs: a long sway plus a shorter ripple.
        float mid = firstRibbonHeight + ribbonSpacing * fi
            + swayAmount * swell * sin(x * (swayFrequency + swayFrequencyStep * fi) + t + fi * 1.9)
            + rippleAmount * swell * sin(x * (rippleFrequency - rippleFrequencyStep * fi) - t * 0.8 + fi * 0.7);
        // How wide it is there, so it twists like silk.
        float halfWidth = ribbonWidthBase + ribbonWidthVariation * (0.5 + 0.5 * sin(x * ribbonWidthFrequency + t * 0.6 + fi * 2.3));

        float dy = uv.y - mid;
        float body = 1.0 - smoothstep(0.0, halfWidth, abs(dy));
        float edge = exp(-pow((abs(dy) - halfWidth) / edgeSharpness, 2.0));

        // Ribbons use the three colors in turn, from the bottom group up.
        float group = floor(fi * 3.0 / max(ribbons, 1.0));
        vec3 tint = group < 0.5 ? ribbonColor1.rgb : (group < 1.5 ? ribbonColor2.rgb : ribbonColor3.rgb);
        col += tint * (body * fillStrength + edge * edgeStrength);
    }

    fragColor = vec4(min(col, vec3(1.0)), 1.0) * qt_Opacity;
}
