const std = @import("std");
const ziggy_core = @import("ziggy_core");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const runtime_mod = ziggy_core.runtime;
    const comps = ziggy_core.zcs.components;
    const log = ziggy_core.support.log;

    var rt = try runtime_mod.ZiggyRuntime.init(allocator);
    defer rt.deinit();

    const scene = &rt.scene;

    // Player
    const player = try scene.createEntity("Player");
    try scene.addTransform(player, comps.Transform{
        .position = .{ 0.0, 0.0, 0.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .scale = .{ 1.0, 1.0, 1.0 },
    });
    try scene.addVelocity(player, comps.Velocity{ .value = .{ 1.0, 0.0, 0.0 } });

    // Camera looking at the player
    const cam_ent = try scene.createEntity("MainCamera");
    try scene.addTransform(cam_ent, comps.Transform{
        .position = .{ 0.0, 5.0, 10.0 }, // above and behind
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .scale = .{ 1.0, 1.0, 1.0 },
    });
    try scene.addCamera(cam_ent, comps.Camera{
        .fov_y = std.math.degreesToRadians(60.0),
        .near = 0.1,
        .far = 200.0,
        .aspect = 16.0 / 9.0,
        .target = .{ 0.0, 0.0, 0.0 }, // look at origin (where player starts)
        .up = .{ 0.0, 1.0, 0.0 },
    });

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        rt.update();

        if (scene.getTransform(cam_ent)) |t_cam| {
            const wx = t_cam.world_matrix[12];
            const wy = t_cam.world_matrix[13];
            const wz = t_cam.world_matrix[14];

            log.info(
                "Frame {d}: cam world pos = ({d:.3}, {d:.3}, {d:.3})",
                .{ i, wx, wy, wz },
            );
        }

        std.time.sleep(16_666_667);
    }
}
