const std = @import("std");
const comps = @import("components.zig");

pub const EntityId = comps.EntityId;

pub const Entity = struct {
    id: EntityId,
    name: []const u8,

    parent: ?EntityId = null,
    first_child: ?EntityId = null,
    next_sibling: ?EntityId = null,

    layer: u8 = 0,
    tags: u32 = 0,
};

pub const Tag = enum(u5) {
    Player,
    Enemy,
    Projectile,
    UI,
    Environment,
    Ground,
    Interactable,
    Collectable,
    Destructible,
    Untagged,
    Respawn,
    EditorOnly,
    MainCamera,
    Finish,
    GameController,
    Trigger,
    // add more as needed
};

fn tagMask(tag: Tag) u32 {
    return @as(u32, 1) << @intFromEnum(tag);
}

pub const ZiggyScene = struct {
    allocator: std.mem.Allocator,

    next_entity_id: EntityId,
    entities: std.AutoHashMap(EntityId, Entity),

    // component storage
    transforms: std.AutoHashMap(EntityId, comps.Transform),
    velocities: std.AutoHashMap(EntityId, comps.Velocity),
    cameras: std.AutoHashMap(EntityId, comps.Camera),
    sprites2d: std.AutoHashMap(EntityId, comps.Sprite2D),

    pub fn init(allocator: std.mem.Allocator) !ZiggyScene {
        return ZiggyScene{
            .allocator = allocator,
            .next_entity_id = 1,
            .entities = std.AutoHashMap(EntityId, Entity).init(allocator),
            .transforms = std.AutoHashMap(EntityId, comps.Transform).init(allocator),
            .velocities = std.AutoHashMap(EntityId, comps.Velocity).init(allocator),
            .cameras = std.AutoHashMap(EntityId, comps.Camera).init(allocator),
            .sprites2d = std.AutoHashMap(EntityId, comps.Sprite2D).init(allocator),
        };
    }

    pub fn deinit(self: *ZiggyScene) void {
        var it = self.entities.valueIterator();
        while (it.next()) |ent| {
            self.allocator.free(ent.name);
        }

        self.entities.deinit();
        self.transforms.deinit();
        self.velocities.deinit();
        self.cameras.deinit();
        self.sprites2d.deinit();
    }

    pub fn createEntity(self: *ZiggyScene, name: []const u8) !EntityId {
        const id = self.next_entity_id;
        self.next_entity_id += 1;

        const ent = Entity{
            .id = id,
            .name = try self.dupString(name),
            .parent = null,
            .first_child = null,
            .next_sibling = null,
        };

        try self.entities.put(id, ent);
        return id;
    }

    pub const Error = error{
        UnknownEntity,
    };

    pub fn setLayer(self: *ZiggyScene, id: EntityId, layer: u8) !void {
        var ent = self.entities.get(id) orelse return Error.UnknownEntity;
        ent.layer = layer;
        try self.entities.put(id, ent);
    }

    pub fn getLayer(self: *ZiggyScene, id: EntityId) ?u8 {
        if (self.entities.get(id)) |ent| {
            return ent.layer;
        }
        return null;
    }

    pub fn addTag(self: *ZiggyScene, id: EntityId, tag: Tag) !void {
        var ent = self.entities.get(id) orelse return Error.UnknownEntity;
        ent.tags |= tagMask(tag);
        try self.entities.put(id, ent);
    }

    pub fn removeTag(self: *ZiggyScene, id: EntityId, tag: Tag) !void {
        var ent = self.entities.get(id) orelse return Error.UnknownEntity;
        ent.tags &= ~tagMask(tag);
        try self.entities.put(id, ent);
    }

    pub fn hasTag(self: *ZiggyScene, id: EntityId, tag: Tag) bool {
        if (self.entities.get(id)) |ent| {
            return (ent.tags & tagMask(tag)) != 0;
        }
        return false;
    }

    pub const TagQueryItem = struct {
        id: EntityId,
        entity: *Entity,
    };

    pub const TagQuery = struct {
        it: std.AutoHashMap(EntityId, Entity).Iterator,
        mask: u32,

        pub fn next(self: *TagQuery) ?TagQueryItem {
            while (self.it.next()) |entry| {
                const ent = entry.value_ptr;
                if ((ent.tags & self.mask) != 0) {
                    return TagQueryItem{
                        .id = entry.key_ptr.*,
                        .entity = ent,
                    };
                }
            }
            return null;
        }
    };

    pub fn queryByTag(self: *ZiggyScene, tag: Tag) TagQuery {
        return .{
            .it = self.entities.iterator(),
            .mask = tagMask(tag),
        };
    }
    pub fn destroyEntity(self: *ZiggyScene, id: EntityId) void {
        if (self.entities.get(id)) |ent| {
            // detach from parent and siblings
            if (ent.parent) |p| {
                self.detachFromParent(id, p);
            }
            // recursively destroy children
            var child_opt = ent.first_child;
            while (child_opt) |child_id| {
                const child_ent = self.entities.get(child_id).?;
                child_opt = child_ent.next_sibling;
                self.destroyEntity(child_id);
            }
        }

        // remove components
        _ = self.transforms.remove(id);
        // later: remove from other component maps

        // remove entity and free its name
        if (self.entities.remove(id)) |ent| {
            self.allocator.free(ent.name);
        }
    }

    fn detachFromParent(self: *ZiggyScene, id: EntityId, parent_id: EntityId) void {
        const parent = self.entities.get(parent_id) orelse return;

        var prev_opt: ?EntityId = null;
        var child_opt = parent.first_child;

        while (child_opt) |child_id| {
            if (child_id == id) {
                if (prev_opt) |prev_id| {
                    var prev_ent = self.entities.get(prev_id).?;
                    prev_ent.next_sibling = self.entities.get(child_id).?.next_sibling;
                    self.entities.put(prev_id, prev_ent) catch {};
                } else {
                    var p = parent;
                    p.first_child = self.entities.get(child_id).?.next_sibling;
                    self.entities.put(parent_id, p) catch {};
                }
                break;
            }
            prev_opt = child_opt;
            child_opt = self.entities.get(child_id).?.next_sibling;
        }
    }

    pub fn setParent(self: *ZiggyScene, child_id: EntityId, parent_id: ?EntityId) !void {
        // remove from old parent if any
        if (self.entities.get(child_id)) |ent| {
            if (ent.parent) |old_parent| {
                self.detachFromParent(child_id, old_parent);
            }
        }

        if (parent_id) |pid| {
            var parent = self.entities.get(pid) orelse return error.InvalidParent;
            // push child at front of parent's children list
            const old_first = parent.first_child;
            parent.first_child = child_id;
            try self.entities.put(pid, parent);

            var child = self.entities.get(child_id).?;
            child.parent = parent_id;
            child.next_sibling = old_first;
            try self.entities.put(child_id, child);
        } else {
            // no parent = root
            var child = self.entities.get(child_id).?;
            child.parent = null;
            child.next_sibling = null;
            try self.entities.put(child_id, child);
        }
    }

    pub fn addTransform(self: *ZiggyScene, id: EntityId, transform: comps.Transform) !void {
        try self.transforms.put(id, transform);
    }

    pub fn getTransform(self: *ZiggyScene, id: EntityId) ?*comps.Transform {
        return self.transforms.getPtr(id);
    }

    pub fn addVelocity(self: *ZiggyScene, id: EntityId, v: comps.Velocity) !void {
        try self.velocities.put(id, v);
    }

    pub fn getVelocity(self: *ZiggyScene, id: EntityId) ?*comps.Velocity {
        return self.velocities.getPtr(id);
    }

    fn dupString(self: *ZiggyScene, s: []const u8) ![]u8 {
        const buf = try self.allocator.alloc(u8, s.len);
        @memcpy(buf, s);
        return buf;
    }

    // ─────────────────────────────────────────────
    // Simple query API
    // ─────────────────────────────────────────────

    pub const TransformQueryItem = struct {
        id: EntityId,
        transform: *comps.Transform,
    };

    pub const TransformQuery = struct {
        it: std.AutoHashMap(EntityId, comps.Transform).Iterator,

        pub fn next(self: *TransformQuery) ?TransformQueryItem {
            if (self.it.next()) |entry| {
                return TransformQueryItem{
                    .id = entry.key_ptr.*,
                    .transform = entry.value_ptr,
                };
            }
            return null;
        }
    };

    pub fn queryTransforms(self: *ZiggyScene) TransformQuery {
        return .{ .it = self.transforms.iterator() };
    }

    pub const MoveQueryItem = struct {
        id: EntityId,
        transform: *comps.Transform,
        velocity: *comps.Velocity,
    };

    pub const MoveQuery = struct {
        scene: *ZiggyScene,
        it: std.AutoHashMap(EntityId, comps.Velocity).Iterator,

        pub fn next(self: *MoveQuery) ?MoveQueryItem {
            while (self.it.next()) |entry| {
                const id = entry.key_ptr.*;
                const vel = entry.value_ptr;

                if (self.scene.getTransform(id)) |t| {
                    return MoveQueryItem{
                        .id = id,
                        .transform = t,
                        .velocity = vel,
                    };
                }
            }
            return null;
        }
    };

    pub fn queryMoveables(self: *ZiggyScene) MoveQuery {
        return .{
            .scene = self,
            .it = self.velocities.iterator(),
        };
    }

    pub fn addCamera(self: *ZiggyScene, id: EntityId, cam: comps.Camera) !void {
        try self.cameras.put(id, cam);
    }

    pub fn getCamera(self: *ZiggyScene, id: EntityId) ?*comps.Camera {
        return self.cameras.getPtr(id);
    }

    pub fn addSprite2D(self: *ZiggyScene, id: EntityId, sprite: comps.Sprite2D) !void {
        try self.sprites2d.put(id, sprite);
    }

    pub fn getSprite2D(self: *ZiggyScene, id: EntityId) ?*comps.Sprite2D {
        return self.sprites2d.getPtr(id);
    }
};
