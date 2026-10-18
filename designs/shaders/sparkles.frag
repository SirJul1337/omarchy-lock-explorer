#version 440
// Drifting sparkles over the XMB waves, drawn per pixel.
//
// This follows the particle layer of
//   https://linkev.github.io/PlayStation-3-XMB/ (particles.js, particles-settings.js)
// The page draws 2000 point sprites that wobble about and twinkle, added on top
// of the picture. A fragment shader cannot loop over thousands of points, so
// the screen is cut into cells with one sparkle each (about `count` of them)
// that wobbles inside its cell and twinkles with the page's alpha formula.
// Three layers of different cell size and drift give the spread of sizes.
//
// Build: qsb --qt6 -o sparkles.frag.qsb sparkles.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;            // seconds of drift
    float aspect;          // width / height
    float viewHeight;      // pixels
    vec4 color;            // sparkle tint (white on the page)
    float count;           // particles, in total
    float particleOpacity;
    float sizeBase;        // pixels
    float sizeVar;         // pixels
    float particleFlowSpeed;
};

// A hash without sin(), which is much cheaper on a small GPU.
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// One layer: cells of `cell` clip units, drifting by `drift`.
float layer(vec2 q, float cell, vec2 drift, float seed, float t) {
    vec2 p = q / cell + drift * t;
    vec2 id = floor(p);
    vec2 f = fract(p);

    float h1 = hash(id + seed);
    float h2 = hash(id * 1.37 + seed + 7.0);
    float h3 = hash(id * 2.11 + seed + 13.0);

    // Sits near the middle of its cell and wobbles about.
    vec2 at = vec2(0.5) + 0.3 * vec2(
        sin(t * (h1 + 0.5) * 1.3 + h2 * 20.0),
        sin(t * (h2 + 0.5) * 1.1 + h1 * 30.0));
    at += (vec2(h1, h2) - 0.5) * 0.2;

    // Page: size = seed.z * sizeVar + sizeBase with seed.z = pow(rand, 8) + 0.1.
    float sz = (pow(h3, 8.0) + 0.1) * sizeVar + sizeBase;
    float radius = 0.5 * sz / (0.5 * viewHeight) / cell;   // in cells
    float d = dot(f - at, f - at) / (radius * radius);
    if (d >= 1.0) return 0.0;
    float sparkle = (1.0 - d) * (1.0 - d);

    // The page's twinkle.
    float tw = t * particleFlowSpeed;
    float op = mix(sin(tw * (h1 + 0.5) * 12.0 + h2 * 10.0),
                   sin(tw * (h2 + 1.5) * 6.0 + h1 * 4.0), 0.5) * h1 + h2;
    float a = op * op * (1.0 - fract(h1 + tw * 0.00285));
    return clamp(a, 0.0, 1.0) * sparkle;
}

void main() {
    vec2 q = vec2((qt_TexCoord0.x * 2.0 - 1.0) * aspect, 1.0 - qt_TexCoord0.y * 2.0);
    // About `count` cells over the area (2 * aspect * 2), split over 3 layers.
    float cell = sqrt(4.0 * aspect / max(count, 1.0) * 3.0);

    float a = layer(q, cell, vec2(0.020, 0.006), 0.0, time)
            + layer(q, cell * 1.3, vec2(-0.012, 0.010), 31.0, time)
            + layer(q, cell * 1.7, vec2(0.008, -0.014), 67.0, time);
    a *= particleOpacity;

    // Added on top: premultiplied colour with no coverage.
    fragColor = vec4(color.rgb * a, 0.0) * qt_Opacity;
}
