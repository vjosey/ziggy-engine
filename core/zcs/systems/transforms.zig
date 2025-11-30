const std = @import("std");
const zcs_scene = @import("../scene.zig");
const comps = @import("../components.zig");

pub fn updateWorldTransforms(scene: *zcs_scene.ZiggyScene) void {
    // update all root entities (no parent)
    var it = scene.entities.iterator();
    while (it.next()) |entry| {
        const id = entry.key_ptr.*;
        const ent = entry.value_ptr.*;
        if (ent.parent == null) {
            updateSubtree(scene, id, null);
        }
    }
}

fn updateSubtree(scene: *zcs_scene.ZiggyScene, id: zcs_scene.EntityId, parent_world: ?[16]f32) void {
    const ent = scene.entities.get(id) orelse return;
    if (scene.getTransform(id)) |t| {
        // For now: build a simple translation matrix; later add rotation/scale
        var world = identityMat4();
        world[12] = t.position[0];
        world[13] = t.position[1];
        world[14] = t.position[2];

        if (parent_world) |pw| {
            t.world_matrix = mulMat4(pw, world);
        } else {
            t.world_matrix = world;
        }

        // recurse into children
        var child_opt = ent.first_child;
        while (child_opt) |child_id| {
            updateSubtree(scene, child_id, t.world_matrix);
            const child_ent = scene.entities.get(child_id).?;
            child_opt = child_ent.next_sibling;
        }
    } else {
        // no transform; still traverse children
        var child_opt = ent.first_child;
        while (child_opt) |child_id| {
            updateSubtree(scene, child_id, parent_world);
            const child_ent = scene.entities.get(child_id).?;
            child_opt = child_ent.next_sibling;
        }
    }
}

// Very barebones mat4 helpers (column-major assumed)
fn identityMat4() [16]f32 {
    return .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
}

fn mulMat4(a: [16]f32, b: [16]f32) [16]f32 {
    var out: [16]f32 = undefined;
    var r: usize = 0;
    while (r < 4) : (r += 1) {
        var c: usize = 0;
        while (c < 4) : (c += 1) {
            out[c + r * 4] =
                a[0 + r * 4] * b[c + 0 * 4] +
                a[1 + r * 4] * b[c + 1 * 4] +
                a[2 + r * 4] * b[c + 2 * 4] +
                a[3 + r * 4] * b[c + 3 * 4];
        }
    }
    return out;
}
