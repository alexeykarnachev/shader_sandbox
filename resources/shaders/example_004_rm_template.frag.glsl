in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

struct RayMarchResult {
    int i;
    vec3 p;
    vec3 n;
    vec3 ro;
    vec3 rd;
    float dist;
    float sd_last;
    float sd_min;
    float sd_min_shape;
};

float get_sd_shape(vec3 p) {
    return length(p) - 1.0;
}

#define RM_MAX_DIST 100.0
#define RM_MAX_N_STEPS 64
#define RM_EPS 0.0001
RayMarchResult march(vec3 ro, vec3 rd) {
    // ------------------------------------------
    // Signed distances
    RayMarchResult rm = RayMarchResult(
            0, // i - ray march last iteration index
            ro, // p - ray's last position
            vec3(0.0), // n - normal, will be 0-vec if the ray hits nothing
            ro, // ro - ray origin, i.e camera position (doesn't change)
            rd, // rd - ray direction at very beginning (doesn't change)
            0.0, // dist - ray total traveled distance
            0.0, // sd_last - min sd only on the last step
            RM_MAX_DIST, // sd_min - min sd ever seen
            RM_MAX_DIST // sd_min_shape - min sd to the shape ever seen
        );

    for (; rm.i < RM_MAX_N_STEPS; ++rm.i) {
        rm.p = rm.ro + rm.rd * rm.dist;

        float sd_step_shape = get_sd_shape(rm.p);

        rm.sd_min_shape = min(rm.sd_min_shape, sd_step_shape);

        rm.sd_last = RM_MAX_DIST;
        rm.sd_last = min(rm.sd_last, sd_step_shape);

        rm.sd_min = min(rm.sd_min, rm.sd_last);

        rm.dist += rm.sd_last;

        if (rm.sd_last < RM_EPS || rm.dist > RM_MAX_DIST) {
            break;
        }
    }

    // ------------------------------------------
    // Normals
    if (rm.sd_last < RM_EPS) {
        float h = RM_EPS;
        vec3 eps = vec3(h, 0.0, 0.0);
        rm.n = normalize(vec3(
                    get_sd_shape(rm.p + eps.xyy) - get_sd_shape(rm.p - eps.xyy),
                    get_sd_shape(rm.p + eps.yxy) - get_sd_shape(rm.p - eps.yxy),
                    get_sd_shape(rm.p + eps.yyx) - get_sd_shape(rm.p - eps.yyx)
                ));
    }

    return rm;
}

// -----------------------------------------------------------------------
// Light, materials, colors
struct Light {
    vec3 direction;
    vec3 color;
    float intensity;
};

struct Material {
    vec3 color;
    float shininess;
};

vec3 get_color(
    RayMarchResult rm,
    Light light,
    Material material
) {
    vec3 normal = rm.n;
    vec3 view_dir = normalize(rm.ro - rm.p);
    vec3 light_color = light.color * light.intensity;

    vec3 diffuse = light_color * material.color * max(dot(normal, -light.direction), 0.0);

    vec3 reflect_dir = reflect(light.direction, normal);
    vec3 specular = light_color * pow(max(dot(view_dir, reflect_dir), 0.0), max(material.shininess, 1.0));

    vec3 color = diffuse + specular;

    return color;
}

// -----------------------------------------------------------------------
void main() {
    // Point on the screen x, y in [-1, 1], z == 0.0
    vec2 screen_pos = vs_uv * 2.0 - 1.0;
    screen_pos.x *= u_aspect; // Correct for aspect ratio

    // Camera setup
    float fov = radians(70.0);
    float screen_dist = 1.0 / tan(0.5 * fov);
    vec3 cam_pos = vec3(0.0, 5.0 * sin(u_time), -5.0);
    vec3 look_at = vec3(0.0, 0.0, 0.0);

    // Calculate camera basis vectors
    vec3 forward = normalize(look_at - cam_pos);
    vec3 world_up = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(forward, world_up));
    vec3 up = normalize(cross(right, forward));

    // Calculate ray direction by creating a point on the virtual screen
    // and getting direction from camera to that point
    vec3 screen_center = cam_pos + forward * screen_dist;
    vec3 screen_point = screen_center + // Screen position
            right * screen_pos.x + // Offset horizontally
            up * screen_pos.y; // Offset vertically

    vec3 ro = cam_pos;
    vec3 rd = normalize(screen_point - cam_pos);

    // Ray March!
    RayMarchResult rm = march(ro, rd);

    // Color
    vec3 color = vec3(0.0);
    Light top_light = Light(vec3(0.0, -1.0, 0.0), vec3(1.0, 0.2, 0.1), 0.001);
    Light bot_light = Light(vec3(0.0, 1.0, 0.0), vec3(1.0, 0.2, 0.1), 1.0);
    Material material = Material(vec3(0.2), 8.0);
    if (rm.sd_min <= RM_EPS) {
        color = get_color(rm, bot_light, material);
        color += get_color(rm, top_light, material);
    }

    float gamma = 2.2;
    color = pow(color, vec3(1.0 / gamma));

    fs_color = vec4(color, 1.0);
}

