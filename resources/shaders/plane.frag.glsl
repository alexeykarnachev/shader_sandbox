in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;

out vec4 fs_color;

#define PI 3.14159

vec2 sp_to_pp(vec2 sp) {
    float a = (atan(sp.y, sp.x) / PI + 1.0) * 0.5;
    float r = length(sp);
    return vec2(a, r);
}

vec2 pp_to_sp(vec2 pp) {
    float r = pp.y;
    float a = pp.x;
    a = (a * 2.0 * PI) - PI;
    return vec2(r * cos(a), r * sin(a));
}

float quantize(float x, float q) {
    return q * floor(x / q);
}

void main() {
    float time = u_time;
    float zoom = 1.0;

    vec2 sp0 = (vs_uv * 2.0) - 1.0;
    sp0 *= zoom;
    sp0.x *= u_aspect;

    vec3 color = vec3(0.0);
    {
        vec2 pp = sp_to_pp(sp0);
        float a = pp.x;
        float r = pp.y;

        r = 0.6;
        r = r + 0.05 * sin(time + 10.0 * PI * a + 20.0 * PI * pow(a, 8.0));
        r = quantize(r, 0.08);

        pp = vec2(a, r);
        vec2 sp1 = pp_to_sp(pp);

        float d = 1.0 - distance(sp0, sp1);
        d = pow(d, 100.0);

        color = vec3(d);
    }

    fs_color = vec4(color, 1.0);
}
