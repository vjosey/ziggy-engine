const std = @import("std");
const ziggy_core = @import("ziggy_core");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const runtime_mod = ziggy_core.runtime;
    const comps = ziggy_core.zcs.components;
    const log = ziggy_core.support.log;
    const math = ziggy_core.support.math;

    var rt = try runtime_mod.ZiggyRuntime.init(allocator);
    defer rt.deinit();

    const scene = &rt.scene;

    // Parent entity
    const parent = try scene.createEntity("Parent");
    try scene.addTransform(parent, comps.Transform{
        .position = .{ 10.0, 0.0, 0.0 }, // translate +X
        .rotation = math.quatIdentity(), // no rotation (you can change later)
        .scale = .{ 2.0, 2.0, 2.0 }, // uniform scale 2x
        .world_matrix = math.mat4Identity(),
    });

    // Child entity (local position relative to parent)
    const child = try scene.createEntity("Child");
    try scene.addTransform(child, comps.Transform{
        .position = .{ 0.0, 5.0, 0.0 }, // 5 units up in parent's local space
        .rotation = math.quatIdentity(),
        .scale = .{ 1.0, 1.0, 1.0 },
        .world_matrix = math.mat4Identity(),
    });

    // Set hierarchy: Child is a child of Parent
    try scene.setParent(child, parent);

    // Give parent a velocity for extra proof it all stays wired (optional)
    try scene.addVelocity(parent, comps.Velocity{
        .value = .{ 1.0, 0.0, 0.0 }, // move parent along +X
    });

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        rt.update();
        const t = rt.getTime();

        if (scene.getTransform(child)) |tr_child| {
            const m = tr_child.world_matrix;

            // world position is the translation column (indices 12,13,14)
            const wx = m[12];
            const wy = m[13];
            const wz = m[14];

            log.info(
                "Frame {d}, dt={d:.5}, elapsed={d:.5} -> Child world pos = ({d:.3}, {d:.3}, {d:.3})",
                .{ i, t.delta, t.elapsed, wx, wy, wz },
            );
        }

        std.time.sleep(16_666_667);
    }
}
