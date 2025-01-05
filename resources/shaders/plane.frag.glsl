in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

void main() {
    // -------------------------------------------------------------------
    // NOTATION
    // uv - coordinates of the fragment with origin at the bot left corner
    // sp - "screen point" usualy means UVs, but centered by x and by y:
    //      sp = uv * 2.0 - 1.0
    //
    //
    //

    // -------------------------------------------------------------------
    // screen_sp - screen coordinates (origin is at the center of the screen)
    vec2 screen_sp;
    {
        screen_sp = vs_uv * 2.0 - 1.0;
        screen_sp.x *= u_aspect;
    }

    vec3 axis_color;
    {

    }

    vec3 color = vec3(screen_sp, 0.0);
    fs_color = vec4(color, 1.0);
}
