#include "raylib/raylib.h"
#include "raylib/raymath.h"
#include "raylib/rcamera.h"
#include "raylib/rlgl.h"
#include <chrono>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <thread>

// #define SCREEN_WIDTH (2560 / 2)
// #define SCREEN_HEIGHT 1440

#define SCREEN_WIDTH 1280
#define SCREEN_HEIGHT 720

// #define SCREEN_WIDTH 1920
// #define SCREEN_HEIGHT 1080

static const Color BACKGROUND_COLOR = {20, 20, 20, 255};

static Mesh PLANE_MESH;

static Material PLANE_MESH_MATERIAL;

Camera3D CAMERA_DEFAULT = {
    .position = {0.0, 0.5, 1.8},
    .target = {0.0, 0.5, 0.0},
    .up = {0.0, 1.0, 0.0},
    .fovy = 40.0,
    .projection = CAMERA_PERSPECTIVE,
};

float ASPECT = 1.0;
Camera3D CAMERA = CAMERA_DEFAULT;

struct Message {
    std::string text;
    Color color;
    float timeCreated;
};

static Message MESSAGE = {"", WHITE, 0.0f};

static float TIME = 0.0;

// -----------------------------------------------------------------------
// utils
RayCollision isect_ray_plane(Ray ray, Vector3 plane_p, Vector3 plane_normal) {
    RayCollision result = {0};
    result.hit = false;

    // Normalize plane normal
    plane_normal = Vector3Normalize(plane_normal);

    // Check if ray and plane are parallel
    float denom = Vector3DotProduct(plane_normal, ray.direction);

    if (fabs(denom) > 0.0001f) {  // Not parallel
        // Calculate distance to intersection point
        Vector3 diff = Vector3Subtract(plane_p, ray.position);
        float t = Vector3DotProduct(diff, plane_normal) / denom;

        // Check if intersection is in front of ray origin
        if (t >= 0.0f) {
            result.hit = true;
            result.distance = t;
            result.point = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
            result.normal = denom < 0.0f ? plane_normal
                                         : Vector3Scale(plane_normal, -1.0f);
        }
    }

    return result;
}

// -----------------------------------------------------------------------
// shader
std::string get_shader_file_path(const std::string &file_name) {
    auto file_path = "resources/shaders/" + file_name;
    return file_path;
}

std::string load_shader_src(const std::string &file_name) {
    const std::string version_src = "#version 460 core";
    std::ifstream common_file(get_shader_file_path("common.glsl"));
    std::ifstream shader_file(get_shader_file_path(file_name));

    std::stringstream common_stream, shader_stream;
    common_stream << common_file.rdbuf();
    shader_stream << shader_file.rdbuf();

    std::string common_src = common_stream.str();
    std::string shader_src = shader_stream.str();

    std::string full_src = version_src + "\n" + common_src + "\n" + shader_src;

    return full_src;
}

struct ShaderInfo {
    Shader shader;
    bool is_success;
    std::chrono::system_clock::time_point vs_last_modified;
    std::chrono::system_clock::time_point fs_last_modified;
};

static ShaderInfo PLANE_MESH_SHADER_INFO;
static ShaderInfo ERROR_SHADER_INFO;

std::chrono::system_clock::time_point get_last_modified_time(const std::string &file_path
) {
    struct stat result;
    if (stat(file_path.c_str(), &result) == 0) {
        return std::chrono::system_clock::from_time_t(result.st_mtime);
    }
    return std::chrono::system_clock::now();
}

ShaderInfo load_shader(const std::string &vs_file_name, const std::string &fs_file_name) {
    auto vs = load_shader_src(vs_file_name);
    auto fs = load_shader_src(fs_file_name);

    Shader shader = LoadShaderFromMemory(vs.c_str(), fs.c_str());
    bool is_success = true;

    if (!IsShaderReady(shader) || shader.id == rlGetShaderIdDefault()) {
        MESSAGE = {"ERROR: Failed to load shader", RED, (float)GetTime()};
        is_success = false;
    }

    return {
        shader,
        is_success,
        get_last_modified_time(get_shader_file_path(vs_file_name)),
        get_last_modified_time(get_shader_file_path(fs_file_name))
    };
}

void update_shader() {
    static int counter = 0;
    if (++counter % 10 != 0) return;

    auto vs_current_time = get_last_modified_time(get_shader_file_path("base.vert.glsl"));
    auto fs_current_time = get_last_modified_time(get_shader_file_path("plane.frag.glsl")
    );

    if (vs_current_time > PLANE_MESH_SHADER_INFO.vs_last_modified
        || fs_current_time > PLANE_MESH_SHADER_INFO.fs_last_modified) {

        TIME = 0.0;

        // Add small delay to ensure file write is complete
        std::this_thread::sleep_for(std::chrono::milliseconds(150));

        ShaderInfo shader_info = load_shader("base.vert.glsl", "plane.frag.glsl");
        UnloadShader(PLANE_MESH_SHADER_INFO.shader);
        PLANE_MESH_SHADER_INFO = shader_info;
        PLANE_MESH_MATERIAL.shader = PLANE_MESH_SHADER_INFO.shader;

        if (shader_info.is_success) {
            MESSAGE = {"Shader loaded", GREEN, (float)GetTime()};
        } else {
            MESSAGE = {"Failed to load shader", RED, (float)GetTime()};
            PLANE_MESH_MATERIAL.shader = ERROR_SHADER_INFO.shader;
        }
    }
}

void reset_camera() {
    CAMERA = CAMERA_DEFAULT;
    MESSAGE = {"Camera reset", GREEN, (float)GetTime()};

    if (ASPECT != 1.0) CAMERA.position.z += 1.0;
}

void update_input() {
    if (IsKeyPressed(KEY_R)) {
        reset_camera();
    }

    if (IsKeyPressed(KEY_ONE)) {
        ASPECT = 1.0;
        reset_camera();
    }

    if (IsKeyPressed(KEY_TWO)) {
        ASPECT = 16.0 / 9.0;
        reset_camera();
    }

    TIME += GetFrameTime();
}

void update_camera() {
    static const float rot_speed = 0.003;
    static const float move_speed = 0.01;
    static const float zoom_speed = 0.1;

    bool is_mmb_down = IsMouseButtonDown(2);
    bool is_shift_down = IsKeyDown(KEY_LEFT_SHIFT);
    Vector2 mouse_delta = GetMouseDelta();

    bool is_moving = is_mmb_down && is_shift_down;
    bool is_rotating = is_mmb_down && !is_shift_down;

    // move
    if (is_moving) {
        CameraMoveRight(&CAMERA, -move_speed * mouse_delta.x, true);

        // camera basis
        auto z = GetCameraForward(&CAMERA);
        auto x = Vector3Normalize(Vector3CrossProduct(z, {0.0, 1.0, 0.0}));
        auto y = Vector3Normalize(Vector3CrossProduct(x, z));

        Vector3 up = Vector3Scale(y, move_speed * mouse_delta.y);

        CAMERA.position = Vector3Add(CAMERA.position, up);
        CAMERA.target = Vector3Add(CAMERA.target, up);
    }

    // rotate
    if (is_rotating) {
        CameraYaw(&CAMERA, -rot_speed * mouse_delta.x, true);
        CameraPitch(&CAMERA, rot_speed * mouse_delta.y, true, true, false);
    }

    // zoom
    CameraMoveToTarget(&CAMERA, -GetMouseWheelMove() * zoom_speed);
}

void draw_message() {
    float currentTime = GetTime();
    float messageAge = currentTime - MESSAGE.timeCreated;

    if (messageAge < 10.0f) {
        float alpha = 1.0f - (messageAge / 10.0f);
        Color messageColor = {
            MESSAGE.color.r,
            MESSAGE.color.g,
            MESSAGE.color.b,
            (unsigned char)(255 * alpha)
        };

        int text_height = 30;
        float text_width = MeasureText(MESSAGE.text.c_str(), text_height);
        float text_x = (float)GetScreenWidth() / 2 - text_width / 2;
        float text_y = 10;

        DrawText(MESSAGE.text.c_str(), text_x, text_y, text_height, messageColor);
    }
}

void load() {
    // window
    SetConfigFlags(FLAG_MSAA_4X_HINT);
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "effects");
    SetTargetFPS(60);

    rlEnableDepthTest();

    // meshes
    PLANE_MESH = GenMeshPlane(1.0, 1.0, 2, 2);

    // materials
    PLANE_MESH_SHADER_INFO = load_shader("base.vert.glsl", "plane.frag.glsl");
    ERROR_SHADER_INFO = load_shader("base.vert.glsl", "example_003_error.frag.glsl");

    PLANE_MESH_MATERIAL = LoadMaterialDefault();
    PLANE_MESH_MATERIAL.shader = PLANE_MESH_SHADER_INFO.shader;
}

void unload() {
    UnloadMesh(PLANE_MESH);

    CloseWindow();
}

void draw_plane() {
    Material material = PLANE_MESH_MATERIAL;
    Shader shader = material.shader;

    Ray mouse_ray = GetMouseRay(GetMousePosition(), CAMERA);
    RayCollision collision = isect_ray_plane(mouse_ray, {0.0, 0.0}, {0.0, 0.0, -1.0});
    Vector2 mouse_pos = {
        Clamp((collision.point.x / ASPECT) + 0.5f, 0.0, 1.0),
        Clamp(collision.point.y, 0.0, 1.0)
    };

    int time_loc = GetShaderLocation(shader, "u_time");
    int aspect_loc = GetShaderLocation(shader, "u_aspect");
    int mouse_pos_loc = GetShaderLocation(shader, "u_mouse_pos");

    SetShaderValue(shader, time_loc, &TIME, SHADER_UNIFORM_FLOAT);
    SetShaderValue(shader, aspect_loc, &ASPECT, SHADER_UNIFORM_FLOAT);
    SetShaderValue(shader, mouse_pos_loc, &mouse_pos, SHADER_UNIFORM_VEC2);

    // translate
    Matrix t = MatrixTranslate(0.0, 0.5, 0.0);

    // scale
    Matrix s = MatrixScale(ASPECT, 1.0, 1.0);

    // rotate
    Matrix r = MatrixRotateX(0.5 * PI);

    // R(S(T(P)))
    Matrix transform = MatrixMultiply(r, MatrixMultiply(s, t));

    DrawMesh(PLANE_MESH, material, transform);
}

int main() {
    load();

    while (!WindowShouldClose()) {
        update_shader();
        update_input();
        update_camera();

        BeginDrawing();
        ClearBackground(BACKGROUND_COLOR);

        BeginMode3D(CAMERA);

        draw_plane();
        DrawGrid(10, 1.0);

        EndMode3D();

        draw_message();
        DrawFPS(10, 10);
        EndDrawing();
    }

    unload();
}
