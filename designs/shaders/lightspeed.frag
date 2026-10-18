#version 440
// Lightspeed star field, drawn per pixel so the CPU does no per-frame work.
//
// The screen is cut into SECTORS wedges around the middle. Each wedge holds one
// star that flies out along its own ray, stretching into a streak as speed
// rises. Position along the ray comes from `depth`, the distance travelled so
// far, so the same star loops back out of the distance when it flies past.
//
// Build: qsb --qt6 -o lightspeed.frag.qsb lightspeed.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float depth;
    float speed;
    float pad;
    vec2 viewSize;
    vec4 base;
    vec4 accent;
};

const float SECTORS = 360.0;
const float TAU = 6.2831853;

float hash(float n) {
    return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * viewSize;
    float R = length(p);
    float reach = 0.5 * length(viewSize);
    float phi = atan(p.y, p.x);
    float scaled = (phi + 3.1415927) / TAU * SECTORS;
    float sector = floor(scaled);
    // This wedge and whichever neighbour the pixel sits closest to.
    float nearer = fract(scaled) < 0.5 ? -1.0 : 1.0;

    vec3 color = vec3(0.0);
    float cover = 0.0;

    for (int d = 0; d < 2; d++) {
        float k = mod(sector + (d == 0 ? 0.0 : nearer) + SECTORS, SECTORS);
        float theta = (k + hash(k * 1.7)) / SECTORS * TAU - 3.1415927;
        float rho = 0.03 + sqrt(hash(k * 3.1 + 5.0)) * 0.97;
        float off = hash(k * 7.3 + 11.0);
        bool tint = hash(k * 9.1 + 2.0) < 0.2;

        // z runs from 1 (far away) down to 0.95 * rho, then the star respawns.
        float life = 1.0 - 0.95 * rho;
        float z = 1.0 - mod(depth + off * life, life);
        z = max(z, 0.02);

        float tail = min(1.0, z + speed * 0.05);
        float rHead = rho / z * reach;
        float rTail = rho / tail * reach;
        float near = 1.0 - z;
        float alpha = min(1.0, near * 12.0) * (0.2 + 0.8 * pow(near, 1.5));
        float halfW = 0.5 * (0.5 + near * near * 2.4);

        float dphi = mod(phi - theta + 3.1415927 + TAU, TAU) - 3.1415927;
        if (cos(dphi) <= 0.0) continue;
        float across = abs(R * sin(dphi));
        float along = R * cos(dphi);

        float edge = 1.0 - smoothstep(halfW - 0.5, halfW + 0.5, across);
        float ends = smoothstep(rTail - 0.5, rTail + 0.5, along) * (1.0 - smoothstep(rHead - 0.5, rHead + 0.5, along));
        float a = alpha * edge * ends;
        vec3 c = tint ? accent.rgb : base.rgb;
        color += c * a;
        cover = max(cover, a);
    }

    fragColor = vec4(min(color, vec3(1.0)), cover) * qt_Opacity;
}
