const zcs_scene = @import("../scene.zig");
const math = @import("../../support/math.zig");

const ZiggyScene = zcs_scene.ZiggyScene;
const Mat4 = math.Mat4;

pub fn update(scene: *ZiggyScene, dt: f32) void {
    _ = dt; // not used for now

    // Find roots (entities with no parent) and update hierarchy from each.
    var it = scene.entities.iterator();
    while (it.next()) |entry| {
        const id = entry.key_ptr.*;
        const ent = entry.value_ptr;
        if (ent.parent == null) {
            updateEntityRecursive(scene, id, null);
        }
    }
}

fn updateEntityRecursive(
    scene: *ZiggyScene,
    id: zcs_scene.EntityId,
    parent_world: ?*const Mat4,
) void {
    var this_world_ptr: ?*const Mat4 = parent_world;

    // Build local TRS and compute this entity's world matrix if it has a Transform
    if (scene.transforms.getPtr(id)) |t| {
        const local = math.mat4FromTrs(t.position, t.rotation, t.scale);

        if (parent_world) |pw| {
            t.world_matrix = math.mat4Mul(pw.*, local);
        } else {
            t.world_matrix = local;
        }

        this_world_ptr = &t.world_matrix;
    }

    // Recurse into children
    const ent = scene.entities.get(id) orelse return;
    var child_opt = ent.first_child;

    while (child_opt) |child_id| {
        const child_ent = scene.entities.get(child_id).?;
        const next = child_ent.next_sibling;

        updateEntityRecursive(scene, child_id, this_world_ptr);

        child_opt = next;
    }
}
