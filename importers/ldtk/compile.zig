const std = @import("std");
const rt = @import("runtime_types.zig");

/// LDtk compiler/loader for Typical TopDown.
/// - Parses LDtk JSON (subset)
/// - Compiles into RuntimeWorld + RuntimeLevels
///
/// Usage idea:
///   var arena = std.heap.ArenaAllocator.init(gpa);
///   defer arena.deinit();
///   const world = try ldtk.loadWorldFromFile(arena.allocator(), "path/to/file.ldtk");
///   const lvl = world.levels_by_name.get("World_Level_0").?;
pub const ldtk = struct {
    // ----------------------------
    // Public API
    // ----------------------------

    pub fn loadWorldFromFile(alloc: std.mem.Allocator, path: []const u8) rt.ImportError!rt.RuntimeWorld {
        const json_bytes = try readWholeFile(alloc, path);
        errdefer alloc.free(json_bytes);

        const base_dir = try dirOfPathDup(alloc, path);

        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();
        const a = arena.allocator();

        const root = parseJsonRoot(a, json_bytes) catch return rt.ImportError.InvalidJson;

        var world = rt.RuntimeWorld{
            .json_version = try getStringDup(alloc, root, "jsonVersion"),
            .base_dir = base_dir,
        };

        // defs
        const defs = getObject(root, "defs") orelse return rt.ImportError.MissingRequiredField;

        try parseTilesets(alloc, &world, defs);
        try parseEnums(alloc, &world, defs);

        // levels[] (Typical TopDown uses levels directly)
        const levels_val = getValue(root, "levels") orelse return rt.ImportError.MissingRequiredField;
        const levels_arr = levels_val.array orelse return rt.ImportError.MissingRequiredField;

        // Pre-size map capacity (nice-to-have)
        try world.levels_by_name.ensureTotalCapacity(alloc, @intCast(levels_arr.items.len));

        // Compile each level
        for (levels_arr.items) |lvl_val| {
            const lvl_obj = lvl_val.object orelse return rt.ImportError.InvalidJson;
            const compiled = try compileLevelFromJson(alloc, &world, lvl_obj);
            world.levels_by_name.putAssumeCapacity(compiled.id.identifier, compiled);
        }

        // Validate tileset uid=1 loadable (Typical TopDown requires it)
        // If it’s loadable but the file doesn’t exist, you can decide whether to hard error now.
        if (world.tilesets.get(1)) |ts| {
            switch (ts.load_state) {
                .Loadable => |p| {
                    // Optional existence check (comment out if you prefer to defer to asset system)
                    if (!fileExists(p.path)) return rt.ImportError.MissingTilesetImage;
                },
                .NotLoadable => return rt.ImportError.MissingTilesetImage,
            }
        } else return rt.ImportError.MissingRequiredField;

        return world;
    }

    // ----------------------------
    // Level compilation
    // ----------------------------

    fn compileLevelFromJson(
        alloc: std.mem.Allocator,
        world: *rt.RuntimeWorld,
        lvl_obj: std.json.Value.ObjectMap,
    ) rt.ImportError!rt.RuntimeLevel {
        const identifier = try getStringDup(alloc, .{ .object = lvl_obj }, "identifier");
        const iid = try getStringDup(alloc, .{ .object = lvl_obj }, "iid");
        const uid = try getInt(lvl_obj, "uid");
        const pxWid = try getInt(lvl_obj, "pxWid");
        const pxHei = try getInt(lvl_obj, "pxHei");
        const worldX = (getIntOpt(lvl_obj, "worldX") orelse 0);
        const worldY = (getIntOpt(lvl_obj, "worldY") orelse 0);

        const layerInstances_val = getValue(.{ .object = lvl_obj }, "layerInstances") orelse return rt.ImportError.MissingRequiredField;
        const layers_arr = layerInstances_val.array orelse return rt.ImportError.MissingRequiredField;

        // We compile:
        // - tile layers: Default_floor, Custom_floor, Wall_tops
        // - collision grid: Collisions
        // - entities: Entities
        var tile_layers = std.ArrayList(rt.TileLayer).init(alloc);
        defer tile_layers.deinit(); // ownership transferred by toOwnedSlice at end

        var entities = std.ArrayList(rt.RuntimeEntity).init(alloc);
        defer entities.deinit();

        var collision: ?rt.CollisionGrid = null;

        // Iterate all layers
        for (layers_arr.items) |layer_val| {
            const layer = layer_val.object orelse return rt.ImportError.InvalidJson;

            const layer_id = try getStringDup(alloc, .{ .object = layer }, "__identifier");
            const layer_type = try getStringDup(alloc, .{ .object = layer }, "__type");
            const grid_size = @as(u32, @intCast(try getInt(layer, "__gridSize")));
            const c_wid = @as(u32, @intCast(try getInt(layer, "__cWid")));
            const c_hei = @as(u32, @intCast(try getInt(layer, "__cHei")));

            if (std.mem.eql(u8, layer_type, "Entities") and std.mem.eql(u8, layer_id, "Entities")) {
                try compileEntitiesLayer(alloc, &entities, .{ .object = layer });
            } else if (std.mem.eql(u8, layer_type, "IntGrid") and std.mem.eql(u8, layer_id, "Collisions")) {
                collision = try compileCollisionLayer(alloc, .{ .object = layer }, grid_size, c_wid, c_hei);
            } else if (std.mem.eql(u8, layer_type, "Tiles") or std.mem.eql(u8, layer_type, "AutoLayer")) {
                // Typical TopDown: Default_floor (AutoLayer), Custom_floor (Tiles), Wall_tops (AutoLayer)
                if (std.mem.eql(u8, layer_id, "Default_floor") or
                    std.mem.eql(u8, layer_id, "Custom_floor") or
                    std.mem.eql(u8, layer_id, "Wall_tops"))
                {
                    const tileset_uid = try getInt(layer, "__tilesetDefUid");
                    const kind = classifyTileLayerKind(layer_id);

                    const tiles = try compileTilesForLayer(alloc, .{ .object = layer }, layer_type);
                    try tile_layers.append(.{
                        .identifier = layer_id,
                        .kind = kind,
                        .tileset_uid = tileset_uid,
                        .tiles = tiles,
                    });
                }
            } else {
                // Ignore other layer types for v1
            }
        }

        // Enforce required layers exist for the example
        if (!hasTileLayer(tile_layers.items, "Default_floor")) return rt.ImportError.MissingRequiredField;
        if (!hasTileLayer(tile_layers.items, "Custom_floor")) return rt.ImportError.MissingRequiredField;
        if (!hasTileLayer(tile_layers.items, "Wall_tops")) return rt.ImportError.MissingRequiredField;
        if (collision == null) return rt.ImportError.MissingRequiredField;

        // Recommended draw order for runtime convenience:
        // Default_floor -> Custom_floor -> Wall_tops
        sortTileLayersRecommended(tile_layers.items);

        var level = rt.RuntimeLevel{
            .id = .{ .identifier = identifier, .iid = iid, .uid = uid },
            .px_wid = pxWid,
            .px_hei = pxHei,
            .world_x = worldX,
            .world_y = worldY,
            .tile_layers = try tile_layers.toOwnedSlice(),
            .collision = collision,
            .entities = try entities.toOwnedSlice(),
        };

        try level.buildEntityIndex(alloc);
        _ = world; // kept for future cross-level resolution if needed

        return level;
    }

    fn classifyTileLayerKind(layer_id: []const u8) rt.TileLayerKind {
        if (std.mem.eql(u8, layer_id, "Default_floor")) return .DefaultFloor;
        if (std.mem.eql(u8, layer_id, "Custom_floor")) return .CustomFloor;
        if (std.mem.eql(u8, layer_id, "Wall_tops")) return .WallTops;
        return .Other;
    }

    fn hasTileLayer(layers: []const rt.TileLayer, name: []const u8) bool {
        for (layers) |l| if (std.mem.eql(u8, l.identifier, name)) return true;
        return false;
    }

    fn sortTileLayersRecommended(layers: []rt.TileLayer) void {
        // Simple stable order by kind priority
        const Ctx = struct {};
        std.sort.insertion(rt.TileLayer, layers, Ctx{}, struct {
            fn lessThan(_: Ctx, a: rt.TileLayer, b: rt.TileLayer) bool {
                return priority(a.kind) < priority(b.kind);
            }
            fn priority(k: rt.TileLayerKind) u8 {
                return switch (k) {
                    .DefaultFloor => 0,
                    .CustomFloor => 1,
                    .WallTops => 2,
                    .Other => 3,
                };
            }
        }.lessThan);
    }

    fn compileTilesForLayer(
        alloc: std.mem.Allocator,
        layer_val: std.json.Value,
        layer_type: []const u8,
    ) rt.ImportError![]rt.TileInstance {
        //TODO: const obj = layer_val.object orelse return rt.ImportError.InvalidJson;

        const arr_name: []const u8 = if (std.mem.eql(u8, layer_type, "Tiles")) "gridTiles" else "autoLayerTiles";
        const tiles_val = getValue(layer_val, arr_name) orelse return rt.ImportError.MissingRequiredField;
        const tiles_arr = tiles_val.array orelse return rt.ImportError.InvalidJson;

        var out = try alloc.alloc(rt.TileInstance, tiles_arr.items.len);
        for (tiles_arr.items, 0..) |tval, i| {
            const tobj = tval.object orelse return rt.ImportError.InvalidJson;

            const px = try getVec2i(tobj, "px");
            const src = try getVec2i(tobj, "src");

            const tid = try getInt(tobj, "t");
            const flip = @as(u8, @intCast(try getInt(tobj, "f")));
            const alpha = @as(f32, @floatCast(try getFloat(tobj, "a")));

            out[i] = .{
                .px = px,
                .src = src,
                .tile_id = tid,
                .flip = flip,
                .alpha = alpha,
            };
        }

        return out;
    }

    fn compileCollisionLayer(
        alloc: std.mem.Allocator,
        layer_val: std.json.Value,
        grid_size: u32,
        c_wid: u32,
        c_hei: u32,
    ) rt.ImportError!rt.CollisionGrid {
        const obj = layer_val.object orelse return rt.ImportError.InvalidJson;
        const csv_val = getValue(layer_val, "intGridCsv") orelse return rt.ImportError.MissingRequiredField;
        const csv_arr = csv_val.array orelse return rt.ImportError.InvalidJson;

        const expected = @as(usize, c_wid) * @as(usize, c_hei);
        if (csv_arr.items.len != expected) return rt.ImportError.IntGridSizeMismatch;

        var cells = try alloc.alloc(u8, expected);
        for (csv_arr.items, 0..) |v, i| {
            const n = v.integer orelse return rt.ImportError.InvalidJson;
            cells[i] = @intCast(n); // should be 0/1 in Typical TopDown
        }

        _ = obj; // keep for future: intGridValueGroups, etc.

        return .{
            .grid_size = grid_size,
            .c_wid = c_wid,
            .c_hei = c_hei,
            .cells = cells,
        };
    }

    fn compileEntitiesLayer(
        alloc: std.mem.Allocator,
        out_entities: *std.ArrayList(rt.RuntimeEntity),
        layer_val: std.json.Value,
    ) rt.ImportError!void {
        const layer_obj = layer_val.object orelse return rt.ImportError.InvalidJson;

        const ents_val = getValue(layer_val, "entityInstances") orelse return rt.ImportError.MissingRequiredField;
        const ents_arr = ents_val.array orelse return rt.ImportError.InvalidJson;

        try out_entities.ensureTotalCapacity(@intCast(ents_arr.items.len));

        for (ents_arr.items) |e_val| {
            const e_obj = e_val.object orelse return rt.ImportError.InvalidJson;

            const identifier = try getStringDup(alloc, .{ .object = e_obj }, "__identifier");
            const iid = try getStringDup(alloc, .{ .object = e_obj }, "iid");
            const px = try getVec2i(e_obj, "px");
            const w = try getInt(e_obj, "width");
            const h = try getInt(e_obj, "height");

            // Optional icon tile (Items use this)
            const icon_tile = parseIconTileOpt(alloc, .{ .object = e_obj }, "__tile");

            // Fields
            const fields = try compileFieldInstances(alloc, .{ .object = e_obj });

            try out_entities.append(.{
                .identifier = identifier,
                .iid = iid,
                .px = px,
                .size = .{ .x = w, .y = h },
                .fields = fields,
                .icon_tile = icon_tile,
            });
        }

        _ = layer_obj;
    }

    fn compileFieldInstances(
        alloc: std.mem.Allocator,
        ent_val: std.json.Value,
    ) rt.ImportError![]rt.Field {
        const fields_val = getValue(ent_val, "fieldInstances") orelse {
            // Some entities may have no fields (SecretWall).
            return try alloc.alloc(rt.Field, 0);
        };
        const fields_arr = fields_val.array orelse return rt.ImportError.InvalidJson;

        var out = try alloc.alloc(rt.Field, fields_arr.items.len);
        for (fields_arr.items, 0..) |fval, i| {
            const fobj = fval.object orelse return rt.ImportError.InvalidJson;

            const fid = try getStringDup(alloc, .{ .object = fobj }, "__identifier");
            const ftype = try getStringDup(alloc, .{ .object = fobj }, "__type");

            // __value can be null
            const v = getValue(.{ .object = fobj }, "__value") orelse return rt.ImportError.MissingRequiredField;

            const parsed = try parseFieldValue(alloc, ftype, v, fobj);

            out[i] = .{
                .identifier = fid,
                .ty = parsed.ty,
                .value = parsed.value,
            };
        }

        return out;
    }

    const ParsedField = struct {
        ty: rt.FieldType,
        value: rt.FieldValue,
    };

    fn parseFieldValue(
        alloc: std.mem.Allocator,
        ftype: []const u8,
        v: std.json.Value,
        field_obj: std.json.Value.ObjectMap,
    ) rt.ImportError!ParsedField {
        // Typical TopDown field types:
        // - "Int"
        // - "LocalEnum.Item"
        // - "Array<EntityRef>"
        if (std.mem.eql(u8, ftype, "Int")) {
            const n = v.integer orelse return rt.ImportError.InvalidJson;
            return .{ .ty = .Int, .value = .{ .Int = @intCast(n) } };
        }

        if (std.mem.eql(u8, ftype, "LocalEnum.Item")) {
            if (v == .null) return .{ .ty = .LocalEnum_Item, .value = .{ .Null = {} } };

            const s = v.string orelse return rt.ImportError.InvalidJson;
            const dup = try alloc.dupe(u8, s);
            // Note: item icon tile metadata may also exist in fieldInstance.__tile (not required for logic).
            _ = parseIconTileOpt(alloc, .{ .object = field_obj }, "__tile");
            return .{ .ty = .LocalEnum_Item, .value = .{ .EnumString = dup } };
        }

        if (std.mem.eql(u8, ftype, "Array<EntityRef>")) {
            if (v == .null) {
                return .{ .ty = .Array_EntityRef, .value = .{ .EntityRefArray = try alloc.alloc(rt.EntityRef, 0) } };
            }
            const arr = v.array orelse return rt.ImportError.InvalidJson;

            var refs = try alloc.alloc(rt.EntityRef, arr.items.len);
            for (arr.items, 0..) |rv, i| {
                const robj = rv.object orelse return rt.ImportError.InvalidJson;

                const entity_iid = getValue(.{ .object = robj }, "entityIid") orelse return rt.ImportError.MissingRequiredField;
                const e_iid = entity_iid.string orelse return rt.ImportError.InvalidJson;

                const layer_iid = getOptStringDup(alloc, robj, "layerIid");
                const level_iid = getOptStringDup(alloc, robj, "levelIid");
                const world_iid = getOptStringDup(alloc, robj, "worldIid");

                refs[i] = .{
                    .entity_iid = try alloc.dupe(u8, e_iid),
                    .layer_iid = layer_iid,
                    .level_iid = level_iid,
                    .world_iid = world_iid,
                };
            }

            return .{ .ty = .Array_EntityRef, .value = .{ .EntityRefArray = refs } };
        }

        // Unknown field types: store as Unknown + Null (v1)
        return .{ .ty = .Unknown, .value = .{ .Null = {} } };
    }

    fn parseIconTileOpt(
        alloc: std.mem.Allocator,
        obj_val: std.json.Value,
        key: []const u8,
    ) ?rt.IconTile {
        const tv = getValue(obj_val, key) orelse return null;
        if (tv == .null) return null;
        const o = tv.object orelse return null;

        const tileset_uid = o.get("tilesetUid") orelse return null;
        const x = o.get("x") orelse return null;
        const y = o.get("y") orelse return null;
        const w = o.get("w") orelse return null;
        const h = o.get("h") orelse return null;

        const ts = tileset_uid.integer orelse return null;
        const xi = x.integer orelse return null;
        const yi = y.integer orelse return null;
        const wi = w.integer orelse return null;
        const hi = h.integer orelse return null;

        // dupe not needed for integers, alloc not used here but kept consistent with other parse helpers
        _ = alloc;

        return .{
            .tileset_uid = @intCast(ts),
            .x = @intCast(xi),
            .y = @intCast(yi),
            .w = @intCast(wi),
            .h = @intCast(hi),
        };
    }

    // ----------------------------
    // defs parsing
    // ----------------------------

    fn parseTilesets(alloc: std.mem.Allocator, world: *rt.RuntimeWorld, defs: std.json.Value) rt.ImportError!void {
        const tilesets_val = getValue(defs, "tilesets") orelse return rt.ImportError.MissingRequiredField;
        const arr = tilesets_val.array orelse return rt.ImportError.InvalidJson;

        try world.tilesets.ensureTotalCapacity(alloc, @intCast(arr.items.len));

        for (arr.items) |tsv| {
            const o = tsv.object orelse return rt.ImportError.InvalidJson;

            const uid = try getInt(o, "uid");
            const ident = try getStringDup(alloc, .{ .object = o }, "identifier");
            const tgs = @as(u32, @intCast(try getInt(o, "tileGridSize")));

            const px_w = @as(u32, @intCast(getIntOpt(o, "pxWid") orelse 0));
            const px_h = @as(u32, @intCast(getIntOpt(o, "pxHei") orelse 0));

            const rel = getValue(.{ .object = o }, "relPath");
            var load_state: rt.Tileset.LoadState = .{ .NotLoadable = {} };

            if (rel) |rv| {
                if (rv != .null) {
                    const rel_s = rv.string orelse return rt.ImportError.InvalidJson;
                    // Resolve base_dir + relPath into a single path string for now.
                    const resolved = try joinPathDup(alloc, world.base_dir, rel_s);
                    load_state = .{ .Loadable = .{ .path = resolved } };
                }
            }

            world.tilesets.putAssumeCapacity(uid, .{
                .uid = uid,
                .identifier = ident,
                .tile_grid_size = tgs,
                .px_w = px_w,
                .px_h = px_h,
                .load_state = load_state,
            });
        }
    }

    fn parseEnums(alloc: std.mem.Allocator, world: *rt.RuntimeWorld, defs: std.json.Value) rt.ImportError!void {
        const enums_val = getValue(defs, "enums") orelse return rt.ImportError.MissingRequiredField;
        const arr = enums_val.array orelse return rt.ImportError.InvalidJson;

        // Only need LocalEnum.Item for Typical TopDown, but parse all.
        try world.enums.ensureTotalCapacity(alloc, @intCast(arr.items.len));

        for (arr.items) |ev| {
            const o = ev.object orelse return rt.ImportError.InvalidJson;
            const ident = try getStringDup(alloc, .{ .object = o }, "identifier");

            const values_val = getValue(.{ .object = o }, "values") orelse return rt.ImportError.MissingRequiredField;
            const values_arr = values_val.array orelse return rt.ImportError.InvalidJson;

            var vals = try alloc.alloc([]const u8, values_arr.items.len);
            for (values_arr.items, 0..) |vv, i| {
                const vo = vv.object orelse return rt.ImportError.InvalidJson;
                const idv = getValue(.{ .object = vo }, "id") orelse return rt.ImportError.MissingRequiredField;
                const s = idv.string orelse return rt.ImportError.InvalidJson;
                vals[i] = try alloc.dupe(u8, s);
            }

            world.enums.putAssumeCapacity(ident, .{ .identifier = ident, .values = vals });
        }

        // Validate Item enum exists for this sample
        if (!world.enums.contains("Item")) {
            // still not fatal for tiles/collision, but the sample uses it for Item/Door fields
            // choose: error now
            return rt.ImportError.MissingRequiredField;
        }
    }

    // ----------------------------
    // JSON helpers
    // ----------------------------

    fn parseJsonRoot(alloc: std.mem.Allocator, bytes: []const u8) !std.json.Value {
        const parsed = try std.json.parseFromSlice(std.json.Value, alloc, bytes, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        });
        return parsed.value;
    }

    fn getValue(v: std.json.Value, key: []const u8) ?std.json.Value {
        const obj = v.object orelse return null;
        return obj.get(key);
    }

    fn getObject(v: std.json.Value, key: []const u8) ?std.json.Value {
        const val = getValue(v, key) orelse return null;
        if (val.object == null) return null;
        return val;
    }

    fn getStringDup(alloc: std.mem.Allocator, v: std.json.Value, key: []const u8) rt.ImportError![]const u8 {
        const val = getValue(v, key) orelse return rt.ImportError.MissingRequiredField;
        const s = val.string orelse return rt.ImportError.InvalidJson;
        return alloc.dupe(u8, s) catch return rt.ImportError.OutOfMemory;
    }

    fn getOptStringDup(alloc: std.mem.Allocator, obj: std.json.Value.ObjectMap, key: []const u8) ?[]const u8 {
        const v = obj.get(key) orelse return null;
        if (v == .null) return null;
        const s = v.string orelse return null;
        return alloc.dupe(u8, s) catch null;
    }

    fn getInt(obj: std.json.Value.ObjectMap, key: []const u8) rt.ImportError!i32 {
        const v = obj.get(key) orelse return rt.ImportError.MissingRequiredField;
        const n = v.integer orelse return rt.ImportError.InvalidJson;
        return @intCast(n);
    }

    fn getIntOpt(obj: std.json.Value.ObjectMap, key: []const u8) ?i32 {
        const v = obj.get(key) orelse return null;
        const n = v.integer orelse return null;
        return @intCast(n);
    }

    fn getFloat(obj: std.json.Value.ObjectMap, key: []const u8) rt.ImportError!f64 {
        const v = obj.get(key) orelse return rt.ImportError.MissingRequiredField;
        if (v.float) |f| return f;
        if (v.integer) |i| return @floatFromInt(i);
        return rt.ImportError.InvalidJson;
    }

    fn getVec2i(obj: std.json.Value.ObjectMap, key: []const u8) rt.ImportError!rt.Vec2i {
        const v = obj.get(key) orelse return rt.ImportError.MissingRequiredField;
        const a = v.array orelse return rt.ImportError.InvalidJson;
        if (a.items.len < 2) return rt.ImportError.InvalidJson;
        const x = a.items[0].integer orelse return rt.ImportError.InvalidJson;
        const y = a.items[1].integer orelse return rt.ImportError.InvalidJson;
        return .{ .x = @intCast(x), .y = @intCast(y) };
    }

    // ----------------------------
    // Filesystem helpers
    // ----------------------------

    fn readWholeFile(alloc: std.mem.Allocator, path: []const u8) rt.ImportError![]u8 {
        var f = std.fs.cwd().openFile(path, .{}) catch return rt.ImportError.MissingTilesetImage;
        defer f.close();
        const stat = f.stat() catch return rt.ImportError.InvalidJson;
        const buf = alloc.alloc(u8, @intCast(stat.size)) catch return rt.ImportError.OutOfMemory;
        _ = f.readAll(buf) catch return rt.ImportError.InvalidJson;
        return buf;
    }

    fn dirOfPathDup(alloc: std.mem.Allocator, path: []const u8) rt.ImportError![]const u8 {
        // Simple: split on last slash/backslash
        var last: ?usize = null;
        for (path, 0..) |c, i| {
            if (c == '/' or c == '\\') last = i;
        }
        if (last == null) {
            return alloc.dupe(u8, ".") catch return rt.ImportError.OutOfMemory;
        }
        return alloc.dupe(u8, path[0..last.?]) catch return rt.ImportError.OutOfMemory;
    }

    fn joinPathDup(alloc: std.mem.Allocator, a: []const u8, b: []const u8) rt.ImportError![]const u8 {
        // naive join: a + "/" + b (normalize later if needed)
        const sep: []const u8 = "/";
        const out = alloc.alloc(u8, a.len + sep.len + b.len) catch return rt.ImportError.OutOfMemory;
        @memcpy(out[0..a.len], a);
        @memcpy(out[a.len .. a.len + sep.len], sep);
        @memcpy(out[a.len + sep.len ..], b);
        return out;
    }

    fn fileExists(path: []const u8) bool {
        std.fs.cwd().access(path, .{}) catch return false;
        return true;
    }
};
