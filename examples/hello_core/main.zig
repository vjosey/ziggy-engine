const std = @import("std");
const ziggy_core = @import("ziggy_core");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const runtime_mod = ziggy_core.runtime;
    const comps = ziggy_core.zcs.components;

    var rt = try runtime_mod.ZiggyRuntime.init(allocator);
    defer rt.deinit();

    const scene = &rt.scene;

    const e = try scene.createEntity("Player");
    try scene.addTransform(e, comps.Transform{
        .position = .{ 1.0, 2.0, 0.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .scale = .{ 1.0, 1.0, 1.0 },
        .world_matrix = undefined, // will be filled by the transform system
    });

    const dt: f32 = 1.0 / 60.0;

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        rt.update(dt);

        if (scene.getTransform(e)) |t| {
            std.debug.print(
                "Frame {d}, dt={d}: world pos = ({d}, {d}, {d})\n",
                .{ i, dt, t.position[0], t.position[1], t.position[2] },
            );
        }
    }
}
