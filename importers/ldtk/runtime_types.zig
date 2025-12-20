const std = @import("std");

pub const Vec2i = struct { x: i32, y: i32 };
pub const Vec2u = struct { x: u32, y: u32 };

pub const AabbI = struct { x: i32, y: i32, w: i32, h: i32 };

pub const Tileset = struct {
    uid: i32,
    identifier: []const u8,
    tile_grid_size: u32,

    px_w: u32 = 0,
    px_h: u32 = 0,

    /// LDtk relPath resolved relative to .ldtk file directory (if present).
    load_state: LoadState,

    pub const LoadState = union(enum) {
        Loadable: struct { path: []const u8 },
        NotLoadable: void,
    };
};

pub const TileInstance = struct {
    /// Position in level pixel space.
    px: Vec2i,
    /// Source px coordinate in tileset image.
    src: Vec2i,

    tile_id: i32,
    flip: u8,
    alpha: f32 = 1.0,
};

pub const TileLayerKind = enum {
    DefaultFloor,
    CustomFloor,
    WallTops,
    Other,
};

pub const TileLayer = struct {
    identifier: []const u8, // LDtk layer name (e.g. "Default_floor")
    kind: TileLayerKind,
    tileset_uid: i32,
    tiles: []TileInstance,
};

pub const CollisionGrid = struct {
    grid_size: u32,
    c_wid: u32,
    c_hei: u32,
    /// row-major: y*c_wid + x. Values are 0/1 for Typical TopDown.
    cells: []u8,

    pub fn indexOf(self: CollisionGrid, x: u32, y: u32) usize {
        return @as(usize, y) * @as(usize, self.c_wid) + @as(usize, x);
    }

    pub fn isSolid(self: CollisionGrid, x: u32, y: u32) bool {
        if (x >= self.c_wid or y >= self.c_hei) return false;
        return self.cells[self.indexOf(x, y)] != 0;
    }

    pub fn worldPxToCell(self: CollisionGrid, px: Vec2i) Vec2u {
        const gs: i32 = @intCast(self.grid_size);
        // Note: assumes px is non-negative for v1 (Typical TopDown is).
        return .{
            .x = @intCast(@divTrunc(px.x, gs)),
            .y = @intCast(@divTrunc(px.y, gs)),
        };
    }
};

pub const IconTile = struct {
    tileset_uid: i32,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

pub const EntityRef = struct {
    entity_iid: []const u8,
    layer_iid: ?[]const u8 = null,
    level_iid: ?[]const u8 = null,
    world_iid: ?[]const u8 = null,
};

pub const FieldType = enum {
    Int,
    LocalEnum_Item,
    Array_EntityRef,
    Unknown,
};

pub const FieldValue = union(enum) {
    Int: i32,
    /// Store enum string like "KeyA" (Typical TopDown uses LocalEnum.Item)
    EnumString: []const u8,
    EntityRef: EntityRef,
    EntityRefArray: []EntityRef,
    Null: void,
};

pub const Field = struct {
    identifier: []const u8,
    ty: FieldType,
    value: FieldValue,
};

/// ZCS-neutral runtime entity: importer does NOT decide what a "Door" means.
/// Game/ZCS adapter decides how to map identifier+fields to components.
pub const RuntimeEntity = struct {
    identifier: []const u8, // "Player", "Door", "Item", "Button", ...
    iid: []const u8,

    px: Vec2i, // top-left in px
    size: Vec2i, // w/h

    fields: []Field,
    icon_tile: ?IconTile = null,

    pub fn aabb(self: RuntimeEntity) AabbI {
        return .{ .x = self.px.x, .y = self.px.y, .w = self.size.x, .h = self.size.y };
    }

    pub fn getInt(self: RuntimeEntity, name: []const u8) ?i32 {
        for (self.fields) |f| {
            if (std.mem.eql(u8, f.identifier, name) and f.value == .Int) return f.value.Int;
        }
        return null;
    }

    pub fn getEnumString(self: RuntimeEntity, name: []const u8) ?[]const u8 {
        for (self.fields) |f| {
            if (std.mem.eql(u8, f.identifier, name) and f.value == .EnumString) return f.value.EnumString;
        }
        return null;
    }

    pub fn getEntityRefs(self: RuntimeEntity, name: []const u8) ?[]EntityRef {
        for (self.fields) |f| {
            if (std.mem.eql(u8, f.identifier, name) and f.value == .EntityRefArray) return f.value.EntityRefArray;
        }
        return null;
    }
};

pub const LevelId = struct {
    identifier: []const u8,
    iid: []const u8,
    uid: i32,
};

pub const RuntimeLevel = struct {
    id: LevelId,

    px_wid: i32,
    px_hei: i32,

    world_x: i32 = 0,
    world_y: i32 = 0,

    tile_layers: []TileLayer,
    collision: ?CollisionGrid = null,
    entities: []RuntimeEntity,

    /// Map for resolving Button.targets by entity iid at runtime
    entity_index_by_iid: std.StringHashMapUnmanaged(u32) = .{},

    pub fn buildEntityIndex(self: *RuntimeLevel, alloc: std.mem.Allocator) !void {
        self.entity_index_by_iid = .{};
        try self.entity_index_by_iid.ensureTotalCapacity(alloc, @intCast(self.entities.len));
        for (self.entities, 0..) |e, idx| {
            self.entity_index_by_iid.putAssumeCapacity(e.iid, @intCast(idx));
        }
    }

    pub fn findEntityByIid(self: *const RuntimeLevel, iid: []const u8) ?*const RuntimeEntity {
        const idx = self.entity_index_by_iid.get(iid) orelse return null;
        return &self.entities[idx];
    }
};

pub const EnumDef = struct {
    identifier: []const u8, // "Item"
    values: []const []const u8, // ["KeyA","KeyB",...]
};

pub const RuntimeWorld = struct {
    json_version: []const u8,

    base_dir: []const u8, // resolved directory of the .ldtk file (for relPath resolution)

    tilesets: std.AutoHashMapUnmanaged(i32, Tileset) = .{},
    enums: std.StringHashMapUnmanaged(EnumDef) = .{},

    /// Compiled levels keyed by level identifier (e.g. "World_Level_0")
    levels_by_name: std.StringHashMapUnmanaged(RuntimeLevel) = .{},

    pub fn deinit(self: *RuntimeWorld, alloc: std.mem.Allocator) void {
        self.tilesets.deinit(alloc);
        self.enums.deinit(alloc);
        self.levels_by_name.deinit(alloc);
    }
};

pub const ImportError = error{
    InvalidJson,
    MissingRequiredField,
    Unsupported,
    MissingTilesetImage,
    IntGridSizeMismatch,
    OutOfMemory,
};
