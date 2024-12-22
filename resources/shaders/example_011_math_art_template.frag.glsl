in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define PI 3.14159265

struct PolarPoint {
    // a - Angle, rescaled in [0, 1]
    // r - Radius, i.e distance from origin

    float a;
    float r;
};

PolarPoint sp_to_pp(vec2 sp) {
    // Screen point to polar point
    // sp - Screen point, i.e screen coordinated in range [-1, +1]
    // pp - Polar point

    PolarPoint pp;
    pp.a = 0.5 * (atan(-sp.y, -sp.x) / PI + 1.0);
    pp.r = length(sp);

    return pp;
}

vec2 pp_to_sp(PolarPoint pp) {
    float a = pp.a * 2.0 * PI - 1.0;
    return vec2(pp.r * cos(a), pp.r * sin(a));
}

void main() {
    // -------------------------------------------------------------------
    // sp - Screen point, i.e uv, rescaled in [-1, +1]
    vec2 sp = (vs_uv * 2.0) - 1.0;
    sp.x *= u_aspect;

    vec3 color = vec3(0.1);
    fs_color = vec4(color, 1.0);
}
