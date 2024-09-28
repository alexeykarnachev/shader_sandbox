#include "raylib/raylib.h"
#include "raylib/raymath.h"
#include "raylib/rcamera.h"

#define SCREEN_WIDTH 1024
#define SCREEN_HEIGHT 1024

const Color BACKGROUND_COLOR = {20, 20, 20, 255};

Camera3D CAMERA = {
    .position = {5.0, 5.0, 5.0},
    .target = {0.0, 0.0, 0.0},
    .up = {0.0, 1.0, 0.0},
    .fovy = 70.0,
    .projection = CAMERA_PERSPECTIVE,
};

static void update_camera() {
    static const float rot_speed = 0.003;
    static const float move_speed = 0.01;
    static const float zoom_speed = 1.0;

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

int main() {
    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "effects");
    SetTargetFPS(60);

    while (!WindowShouldClose()) {
        update_camera();

        BeginDrawing();
        ClearBackground(BACKGROUND_COLOR);

        BeginMode3D(CAMERA);
        DrawGrid(10, 1.0);
        DrawCube({0.0, 0.0, 0.0}, 1.0, 1.0, 1.0, RED);
        EndMode3D();

        DrawFPS(10, 10);
        EndDrawing();
    }

    CloseWindow();
}
