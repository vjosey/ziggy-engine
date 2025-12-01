const zcs_scene = @import("../scene.zig");
const math = @import("../../support/math.zig");

const ZiggyScene = zcs_scene.ZiggyScene;

/// For each entity that has both Transform + Camera:
/// - Compute world-space position from transform.world_matrix
/// - Build view matrix via lookAt
/// - Build projection via perspective
/// - Cache view, proj, view_proj on the Camera
pub fn update(scene: *ZiggyScene, dt: f32) void {
    _ = dt;

    var it = scene.cameras.iterator();
    while (it.next()) |entry| {
        const id = entry.key_ptr.*;
        const cam = entry.value_ptr;

        if (scene.getTransform(id)) |t| {
            const m = t.world_matrix;
            const eye: math.Vec3 = .{ m[12], m[13], m[14] };

            const target: math.Vec3 = .{
                cam.target[0],
                cam.target[1],
                cam.target[2],
            };
            const up: math.Vec3 = .{
                cam.up[0],
                cam.up[1],
                cam.up[2],
            };

            cam.view = math.mat4LookAt(eye, target, up);
            cam.proj = math.mat4Perspective(cam.fov_y, cam.aspect, cam.near, cam.far);
            cam.view_proj = math.mat4Mul(cam.proj, cam.view);
        }
    }
}
