in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define PI 3.141592

// -----------------------------------------------------------------------
// Simplex 3D Noise
// by Ian McEwan, Stefan Gustavson (https://github.com/stegu/webgl-noise)
vec4 permute(vec4 x) {
    return mod(((x * 34.0) + 1.0) * x, 289.0);
}
vec4 taylorInvSqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    //  x0 = x0 - 0. + 0.0 * C
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1. + 3.0 * C.xxx;

    // Permutations
    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(
                    i.z + vec4(0.0, i1.z, i2.z, 1.0))
                    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
                + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // Gradients
    // ( N*N points uniformly over a square, mapped onto an octahedron.)
    float n_ = 1.0 / 7.0; // N=7
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z); //  mod(p,N*N)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_); // mod(j,N)

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    //Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    float n = 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1),
                    dot(p2, x2), dot(p3, x3))); // [-1 ... +1]

    // n = 0.5 * (n + 1.0); // [0 ... +1]

    return n;
}

// -----------------------------------------------------------------------
vec3 get_axis_color(vec2 sp) {
    float line_width = 0.02;
    float line_smoothness = 0.01;
    vec2 lines = 1.0 - smoothstep(0.0, line_smoothness, abs(sp) - line_width);

    return vec3(lines, 0.0);
}

vec3 get_grid_color(vec2 sp) {
    vec2 uv_cell = fract(sp);
    vec2 sp_cell = (uv_cell * 2.0) - 1.0;

    float line_width = 0.01;
    float line_smoothness = 0.005;

    vec2 lines = 1.0 - smoothstep(0.0, line_smoothness, 1.0 - abs(sp_cell) - line_width);
    float line = max(lines.x, lines.y);
    vec3 color = 0.1 * vec3(1.0, 1.0, 1.0);

    return line * color;
}

vec3 get_line_color(vec2 sp) {
    float t = u_time;

    float x = sp.x;

    float noise_xt = snoise(vec3(x, t, 0.0));
    float noise_xty = snoise(vec3(x, t, sp.y));

    float signal = sin(x * PI) / (1.0 + pow(0.35 * abs(x), 16.0)) + 0.1 * noise_xt;

    float signal_ratio = clamp(pow(abs(sp.x), 1.0), 0.0, 1.0);
    float y = signal_ratio * signal + (1 - signal_ratio) * noise_xty;
    float line_brightness = 0.1 * (15.0 - 10.0 * 2.0 * (noise_xty - 0.5));
    vec3 line_attenuation = vec3(1.0, 160.0, 160.0);

    vec3 signal_color = 1.0 * vec3(0.1, 1.0, 0.0);
    vec3 noise_color = 10.0 * vec3(1.0, 0.3, 0.0);
    vec3 color = signal_ratio * signal_color + (1 - signal_ratio) * noise_color;

    float d = distance(sp, vec2(x, y));
    float line = line_brightness / dot(line_attenuation, vec3(1.0, d, d * d));

    return line * color;
}

void main() {
    vec2 uv = vs_uv;

    float zoomout = 2.0;
    vec2 sp = (uv * 2.0) - 1.0;

    sp *= zoomout;
    sp.x *= u_aspect;

    vec3 color = vec3(0.0);

    // color += get_axis_color(sp);
    color += get_grid_color(sp);
    color += get_line_color(sp);

    fs_color = vec4(color, 1.0);
}
