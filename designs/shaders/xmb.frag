#version 440
// XMB style silk waves, drawn per pixel so the CPU does no per-frame work.
//
// This follows the PlayStation 3 XMB recreation at
//   https://linkev.github.io/PlayStation-3-XMB/
// (spline.js, spline-reverse.js and spline-settings.js). That page draws a mesh
// of 100 rows. Each row is a curve whose height comes from a displacement
// texture, and the fold-over of the rows is what makes the bright silk. A
// fragment shader cannot draw a mesh, so this works the same picture out per
// pixel instead:
//
//   * The mesh sits in clip space with screen y = height and the row index z
//     as depth. Its height is a band, A * sin(phase + rowPhase * z), plus
//     terms that do not depend on the row (ground()).
//   * The page shades it with a fresnel term on the surface normal. In screen
//     space that normal is (-dz/dX, -dz/dY, 1), so nz = |dY/dz| /
//     sqrt(dY/dz^2 + dY/dX^2 + 1) and the brightness is
//     fresnelScale * pow(1 - nz, fresnelPower).
//   * For a pixel (X, Y) the rows that land on it are the z where
//     height(X, z) = Y. With a sine band that is at most two, found directly.
//     Their brightnesses are alpha blended.
//
// Not modelled: the page's "reverse pipeline" (the re* settings), which adds a
// small noise kernel to the band, and the z displacement (ffd*Z, zDetailScale).
// Names below match the page's settings so values can be compared.
//
// Build: qsb --qt6 -o xmb.frag.qsb xmb.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;          // seconds of drift
    float swell;         // 1 normally, more while typing
    float pad0;
    vec4 colorTop;       // background gradient, top
    vec4 colorBottom;    // background gradient, bottom
    vec4 waveColor;      // what the silk is tinted (white on the page)

    float flowSpeed;
    float tension;
    float damping;
    float length;
    float spacing;
    float timeStep;
    float bandAmplitude;
    float bandFreq;      // 6.2 in spline-reverse.js: waves across the screen
    float bandRowPhase;  // 1.7 in spline-reverse.js: phase shift per row
    float bandSecondaryAmp;
    float travelSpeed1;
    float travelAmp1;
    float travelSpeed2;
    float travelAmp2;
    float perturbation;
    float perturbationScale;
    float waveCosAmp;
    float waveBias;
    float waveHeightScale;
    float waveSoftClip;
    float rePipelineBlend;
    float fresnelPower;
    float fresnelScale;
    float waveOpacity;
    float brightness;
    float ffdScale1X;
    float ffdYAmp;
};

const float PI = 3.14159265;

// Everything in the height that does not depend on the row.
float ground(float X, float flow) {
    float u = (X + 1.0) * 0.5;
    float legacy =
        sin(u * PI * 1.3 - flow * travelSpeed1) * travelAmp1 * tension +
        sin(u * PI * 2.8 + flow * travelSpeed2) * travelAmp2 +
        perturbation * perturbationScale * sin((u * (4.0 + length * 2.0) - flow * 0.6) * (spacing * 0.01));
    float secondary = cos(u * 4.8 + flow * 0.09) * bandSecondaryAmp;
    float y = secondary * rePipelineBlend + legacy * (1.0 - rePipelineBlend);
    y += sin(X * ffdScale1X + time * flowSpeed) * ffdYAmp;

    float baseWave = cos(X * 2.0 - time * 0.5 * timeStep) * waveCosAmp + waveBias;
    baseWave *= (1.0 - damping);
    baseWave += tension * sin(X * length + time * flowSpeed * timeStep * 0.25);
    float structured = perturbation * perturbationScale * (
        sin((X * length * 6.0) * spacing * 0.01 + time * flowSpeed * timeStep * 0.7) * 0.5 +
        sin((X * length * 10.0) * spacing * 0.005 - time * flowSpeed * timeStep * 0.35) * 0.25);
    float total = (baseWave + structured) * waveHeightScale;
    total = waveSoftClip * tanh(total / max(waveSoftClip, 1e-4));
    return y - total;
}

void main() {
    vec2 uv = qt_TexCoord0;           // y down
    float X = uv.x * 2.0 - 1.0;       // clip space, y up
    float Y = 1.0 - uv.y * 2.0;

    // The page's background: a smoothstepped gradient from top to bottom.
    float g = smoothstep(0.0, 1.0, uv.y);
    vec3 col = mix(colorTop.rgb, colorBottom.rgb, g);

    float flow = time * flowSpeed * timeStep;
    float u = (X + 1.0) * 0.5;
    float A = bandAmplitude * rePipelineBlend * swell;
    float base = ground(X, flow);
    float raw = (Y - base) / max(A, 1e-4);

    if (abs(raw) < 1.0 + 0.02) {
        float s = clamp(raw, -1.0, 1.0);
        float root = sqrt(max(0.0, 1.0 - s * s));
        float phase0 = flow * 0.25 + u * bandFreq;
        // Slope along X of the row-independent part, by finite difference.
        float e = 0.01;
        float hx = (ground(X + e, flow) - ground(X - e, flow)) / (2.0 * e);
        float period = 2.0 * PI / bandRowPhase;

        float alpha = 0.0;
        for (int i = 0; i < 2; i++) {
            float a = i == 0 ? asin(s) : PI - asin(s);
            float c = i == 0 ? root : -root;
            // The row this solution sits on, wrapped into one period.
            float z = (a - phase0) / bandRowPhase;
            z -= period * floor((z + 0.5 * period) / period);
            if (abs(z) > 1.0) continue;

            float dYdz = A * bandRowPhase * c;
            float dYdX = hx + A * c * bandFreq * 0.5;
            float nz = abs(dYdz) / sqrt(dYdz * dYdz + dYdX * dYdX + 1.0);
            float F = fresnelScale * pow(1.0 - nz, fresnelPower);
            float a1 = F * waveOpacity * brightness;
            alpha = 1.0 - (1.0 - alpha) * (1.0 - a1);
        }
        // Soften the outer edge of the band by a pixel.
        float aa = 2.5 * fwidth(raw);
        alpha *= 1.0 - smoothstep(1.0 - aa, 1.0 + aa, abs(raw));
        col = mix(col, waveColor.rgb, alpha);
    }

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
