const std = @import("std");
const ziggy_core = @import("ziggy_core");
const zcs_scene = ziggy_core.zcs.scene;

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

    const e = try scene.createEntity("Player");
    try scene.addTransform(e, comps.Transform{
        .position = .{ 1.0, 2.0, 0.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .scale = .{ 1.0, 1.0, 1.0 },
        .world_matrix = undefined,
    });

    // 👇 give the Player a velocity so movement_system can do its thing
    try scene.addVelocity(e, comps.Velocity{
        .value = .{ 1.0, 0.0, 0.0 }, // 1 unit/sec in +X
    });

    // Set tags/layers
    try scene.setLayer(e, 1); // e.g. gameplay layer 1
    try scene.addTag(e, zcs_scene.Tag.Player);

    var tq = scene.queryByTag(zcs_scene.Tag.Player);
    while (tq.next()) |item| {
        log.info("Player entity id={d}, layer={d}", .{ item.id, item.entity.layer });
    }
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        rt.update();
        const t = rt.getTime();

        if (scene.getTransform(e)) |tr| {
            log.info(
                "Frame {d}, dt={d:.5}, elapsed={d:.5}: world pos = ({d:.3}, {d:.3}, {d:.3})",
                .{ i, t.delta, t.elapsed, tr.position[0], tr.position[1], tr.position[2] },
            );
        }

        std.time.sleep(16_666_667); // ~60Hz
    }
}
