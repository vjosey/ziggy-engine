const scene_mod = @import("../scene.zig");
const comps = @import("../components.zig");

pub fn update(scene: *scene_mod.ZiggyScene, dt: f32) void {
    var q = scene.queryMoveables();
    while (q.next()) |item| {
        item.transform.position[0] += item.velocity.value[0] * dt;
        item.transform.position[1] += item.velocity.value[1] * dt;
        item.transform.position[2] += item.velocity.value[2] * dt;
    }
}
