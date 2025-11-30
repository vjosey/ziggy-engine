const std = @import("std");
const comps = @import("components.zig");

pub const EntityId = comps.EntityId;

pub const Entity = struct {
    id: EntityId,
    name: []const u8,

    parent: ?EntityId = null,
    first_child: ?EntityId = null,
    next_sibling: ?EntityId = null,
};

pub const ZiggyScene = struct {
    allocator: std.mem.Allocator,

    next_entity_id: EntityId,
    entities: std.AutoHashMap(EntityId, Entity),

    // component storage
    transforms: std.AutoHashMap(EntityId, comps.Transform),

    pub fn init(allocator: std.mem.Allocator) !ZiggyScene {
        return ZiggyScene{
            .allocator = allocator,
            .next_entity_id = 1,
            .entities = std.AutoHashMap(EntityId, Entity).init(allocator),
            .transforms = std.AutoHashMap(EntityId, comps.Transform).init(allocator),
        };
    }

    pub fn deinit(self: *ZiggyScene) void {
        var it = self.entities.valueIterator();
        while (it.next()) |ent| {
            self.allocator.free(ent.name);
        }

        self.entities.deinit();
        self.transforms.deinit();
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

    fn dupString(self: *ZiggyScene, s: []const u8) ![]u8 {
        const buf = try self.allocator.alloc(u8, s.len);
        @memcpy(buf, s);
        return buf;
    }
};
