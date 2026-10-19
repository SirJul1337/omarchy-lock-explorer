#version 440
// SolClock: thin concentric rings around a glowing sun, with the time on top.
// Drawn per pixel, so the CPU does nothing between redraws.
//
// A port of https://jgarza9788.github.io/hawaiian_clock/ (style.css). The page
// stacks, in one box: a repeating radial gradient of rings (black to grey to
// black), a white glow disc over it, the blurred white numbers over that, and
// a black inset shadow at the edges. Then `filter: contrast(2000%)` pushes the
// whole stack to black or white around the middle grey. That filter is what
// makes the picture: it turns the grey ramps of the rings into thin lines, makes
// the glow a hard disc, and makes the numbers show up as thicker lines (where
// the number's white lifts a ramp over the middle grey sooner). Here the sun is
// drawn into the same blurred picture as the numbers, so it gets the same soft,
// blobby edge and runs together with the digits when they meet. The page then
// colors it with a sunset; here the lines are one color and the rest another,
// both set from the theme in SolClock.qml, where every number is explained.
// As on the page, the rings are centred on the sun, and the sun goes round the
// middle of the screen where the time is. (A setting can centre them on the
// screen instead.)
//
// Build: qsb --qt6 -o solclock.frag.qsb solclock.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float sunX;            // the sun, pixels from the left
    float sunY;
    float sunRadius;       // pixels
    float glowSize;        // pixels: how far the glow reaches past the sun
    float glowStrength;    // 0..1
    float glowCurve;       // falloff: 1 is straight, higher keeps it near the sun
    float ringX;           // the rings' middle, pixels from the left
    float ringY;
    float viewWidth;
    float viewHeight;
    float em;              // pixels: the page's 35vh
    float ringSpacing;     // in em
    float peakValue;       // grey at the top of a ring's ramp (the page's #888)
    float contrast;        // the page's contrast(2000%) is 20
    float numberOpacity;   // 0 to 1: how much of its white the numbers add
    float sunOpacity;      // the same for the sun
    float vignetteSize;    // pixels, the page's 25px inset shadow
    float vignetteStrength;
    float ringPhase;       // rings moved outward by this many rings (the ripple)
    float ringSpread;      // 0 keeps the rings evenly spaced, more spreads them outward
    float farDistance;     // pixels from the rings' middle where the rings reach farColor
    float pulseRadius;     // pixels: where the pulse ring is now
    float pulseWidth;      // pixels
    float pulseAmount;     // 0..1: how visible it is now
    vec4 lineColor;
    vec4 farColor;         // the far rings
    vec4 gapColor;
    vec4 pulseColor;
};

// The blurred picture of the time (red) and the sun (green).
layout(binding = 1) uniform sampler2D mask;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * vec2(viewWidth, viewHeight);

    // The rings, round the middle: grey ramps, 0 at the start of a period,
    // peakValue a third of the way along, back to 0 at the end.
    float period = ringSpacing * em;
    float dRing = distance(p, vec2(ringX, ringY));
    // With a spread above 0 the rings are further apart the further out they
    // are, like ripples: the n-th ring sits at period * n^(1 + spread).
    float x = dRing / period;
    float t = fract((ringSpread > 0.0 ? pow(x, 1.0 / (1.0 + ringSpread)) : x) - ringPhase);
    float ramp = t < 1.0 / 3.0 ? t * 3.0 : (1.0 - t) * 1.5;
    float value = ramp * peakValue;


    // A glow round the sun, put in before the cut and under the blurred picture
    // below: it lifts the rings' grey toward white, so the rings get thicker the
    // nearer they are to the sun and run together at its edge.
    float away = distance(p, vec2(sunX, sunY));
    if (glowStrength > 0.0 && away < sunRadius + glowSize) {
        float halo = pow(clamp(1.0 - (away - sunRadius) / max(glowSize, 1.0), 0.0, 1.0), glowCurve);
        value = mix(value, 1.0, halo * glowStrength);
    }

    // The time and the sun, white and see-through, blurred the same way.
    vec4 m = texture(mask, uv);
    value = mix(value, 1.0, m.r * numberOpacity);
    value = mix(value, 1.0, m.g * sunOpacity);

    // A black shadow just inside the edges.
    float edge = min(min(p.x, viewWidth - p.x), min(p.y, viewHeight - p.y));
    if (edge < vignetteSize)
        value = mix(value, 0.0, vignetteStrength * (1.0 - smoothstep(0.0, max(vignetteSize, 1e-3), edge)));

    // The hard contrast: lines, digits and sun are 1, the rest 0.
    float bright = clamp((value - 0.5) * contrast + 0.5, 0.0, 1.0);

    // The rings fade from lineColor near the middle to farColor far from it; the
    // digits and the sun keep lineColor.
    vec3 ringColor = mix(lineColor.rgb, farColor.rgb, smoothstep(0.0, max(farDistance, 1.0), dRing));
    float solid = clamp(max(m.r * numberOpacity * 2.0, m.g * sunOpacity), 0.0, 1.0);
    vec3 line = mix(ringColor, lineColor.rgb, solid);
    vec3 col = mix(gapColor.rgb, line, bright);

    // A pulse running out from the sun, after a key.
    if (pulseAmount > 0.001) {
        float u = (away - pulseRadius) / max(pulseWidth, 1.0);
        col = mix(col, pulseColor.rgb, clamp(exp(-u * u) * pulseAmount, 0.0, 1.0));
    }

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
