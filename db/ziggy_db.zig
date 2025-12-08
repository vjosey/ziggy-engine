const std = @import("std");
const json = std.json;

pub const FieldType = enum {
    Int,
    Float,
    Bool,
    String,
    Enum,
    Ref,
    List,
    Json,
    // Enum, Ref, List, Json, etc. will be added as we flesh out 0.1
};

pub const ListElementType = enum {
    Int,
    Float,
    Bool,
    String,
    Enum,
    Ref,
    Json,
};

pub const FieldDef = struct {
    name: []const u8,
    field_type: FieldType,
    enum_name: ?[]const u8 = null,
    // for Ref or List<Ref>
    ref_table: ?[]const u8 = null,
    list_element_type: ?ListElementType = null,
};

pub const Value = union(enum) {
    Int: i64,
    Float: f64,
    Bool: bool,
    String: []const u8,
    Enum: []const u8, // case name, e.g. "Common"
    Ref: []const u8, // target row key
    List: []Value, // homogeneous list (you know the element type from FieldDef)
    Json: std.json.Value, // raw JSON node
};

pub const Row = struct {
    key: []const u8,
    values: []Value,
    // placeholder; later: values aligned with FieldDef
};

pub const Table = struct {
    name: []const u8,
    fields: []FieldDef,
    rows: []Row,
};

pub const Database = struct {
    tables: []Table,

    pub fn initEmpty() Database {
        return .{ .tables = &.{} };
    }

    pub fn deinit(self: *Database, allocator: std.mem.Allocator) void {
        _ = allocator;
        // later we'll free allocated memory here
        _ = self;
    }
};

pub const LoadOptions = struct {
    // later: toggle validation, logging, etc.
    /// Whether ZiggyDB should validate references (Ref fields).
    /// Default: false (to keep v0.1 lightweight)
    validate_refs: bool = false,

    /// Whether ZiggyDB should validate enum values.
    /// Default: false (can be slow for large data sets)
    validate_enums: bool = false,
    verbose: bool = false,

    /// Optional allocator for JSON DOM temporary structures.
    /// If null → fall back to main allocator.
    json_allocator: ?std.mem.Allocator = null,
};

// Simple placeholder so you can import and call something from Ziggy Studio / examples
pub fn version() []const u8 {
    return "ziggy_db 0.1.0-dev";
}

pub fn loadFromDir(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    options: LoadOptions,
) !Database {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var tables_list = std.ArrayList(Table).init(allocator);
    errdefer {
        // clean up partially built tables if we error
        for (tables_list.items) |*t| {
            deinitTable(t, allocator);
        }
        tables_list.deinit();
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!hasZdbJsonExtension(entry.name)) continue;

        if (options.verbose) {
            std.debug.print("ZiggyDB: loading table file: {s}/{s}\n", .{ dir_path, entry.name });
        }

        const table = try loadSingleTable(allocator, options, &dir, entry.name);
        try tables_list.append(table);
    }

    var db = Database{
        .tables = try tables_list.toOwnedSlice(),
    };

    if (options.validate_refs or options.validate_enums) {
        //TODO: split these into separate functions later
        try validateDatabase(&db, options);
    }

    return db;
}

pub fn createTable(
    allocator: std.mem.Allocator,
    name: []const u8,
) !Table {
    return Table{
        .name = try allocator.dupe(u8, name),
        .fields = &.{},
        .rows = &.{},
    };
}

pub fn addField(
    table: *Table,
    allocator: std.mem.Allocator,
    def: FieldDef,
) !void {
    // allocate new slice
    const new_len = table.fields.len + 1;
    var new = try allocator.alloc(FieldDef, new_len);

    // copy old entries
    std.mem.copy(FieldDef, new, table.fields);

    // duplicate the field name
    const name_copy = try allocator.dupe(u8, def.name);

    // last entry
    new[new_len - 1] = FieldDef{
        .name = name_copy,
        .field_type = def.field_type,
        .list_element_type = def.list_element_type,
        .ref_table = def.ref_table,
    };

    // free old
    if (table.fields.len > 0)
        allocator.free(table.fields);

    table.fields = new;
}

pub fn addRow(
    table: *Table,
    allocator: std.mem.Allocator,
    key: []const u8,
    values: []const Value,
) !void {
    if (values.len != table.fields.len)
        return error.FieldCountMismatch;

    const new_len = table.rows.len + 1;
    var new = try allocator.alloc(Row, new_len);

    // copy existing rows
    std.mem.copy(Row, new, table.rows);

    // create new row
    var vals = try allocator.alloc(Value, values.len);

    for (values, 0..) |v, i| {
        vals[i] = v; // shallow copy (OK because Value owns its memory)
    }

    new[new_len - 1] = Row{
        .key = try allocator.dupe(u8, key),
        .values = vals,
    };

    if (table.rows.len > 0)
        allocator.free(table.rows);

    table.rows = new;
}

/// lookup table by name
pub fn getTable(db: *Database, name: []const u8) ?*Table {
    for (db.tables) |*table| {
        if (std.mem.eql(u8, table.name, name)) {
            return table;
        }
    }
    return null;
}

/// lookup row by key within a table
pub fn getRow(table: *Table, key: []const u8) ?*Row {
    for (table.rows) |*row| {
        if (std.mem.eql(u8, row.key, key)) {
            return row;
        }
    }
    return null;
}

/// get the index of a field by name, or null if not found
pub fn getFieldIndex(table: *const Table, field_name: []const u8) ?usize {
    for (table.fields, 0..) |field, idx| {
        if (std.mem.eql(u8, field.name, field_name)) {
            return idx;
        }
    }
    return null;
}

/// convenience: get value by field name
pub fn getFieldValueByName(
    table: *const Table,
    row: *const Row,
    field_name: []const u8,
) ?*const Value {
    if (getFieldIndex(table, field_name)) |idx| {
        return &row.values[idx];
    }
    return null;
}

fn loadSingleTable(
    allocator: std.mem.Allocator,
    options: LoadOptions,
    dir: *std.fs.Dir,
    file_name: []const u8,
) !Table {
    const json_alloc = options.json_allocator orelse allocator;

    // 1. Read file into memory
    var file = try dir.openFile(file_name, .{});
    defer file.close();

    const file_data = try file.readToEndAlloc(json_alloc, std.math.maxInt(usize));
    defer json_alloc.free(file_data);

    // 2. Parse JSON
    const parse_result = try std.json.parseFromSlice(std.json.Value, json_alloc, file_data, .{});
    defer parse_result.deinit();

    const root = parse_result.value;

    // 3. Expect an object at root
    const root_obj = switch (root) {
        .object => |o| o,
        else => return error.InvalidTableJson,
    };

    // 4. Get "table"
    const table_name = try getStringField(root_obj, "table");

    // 5. Get "fields" and build FieldDef[]
    const fields_val = try getField(root_obj, "fields");
    const fields = try parseFields(allocator, fields_val);

    // 6. Get "rows" and build Row[]
    const rows_val = try getField(root_obj, "rows");
    const rows = try parseRows(allocator, fields, rows_val);

    // 7. Build Table
    return Table{
        .name = try dupString(allocator, table_name),
        .fields = fields,
        .rows = rows,
    };
}

fn hasZdbJsonExtension(name: []const u8) bool {
    return std.mem.endsWith(u8, name, ".zdb.json");
}

fn dupString(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    return try allocator.dupe(u8, s);
}

fn getField(obj: std.json.ObjectMap, key: []const u8) !std.json.Value {
    if (obj.get(key)) |val| {
        return val;
    }
    return error.MissingField;
}

fn getStringField(obj: std.json.ObjectMap, key: []const u8) ![]const u8 {
    const val = try getField(obj, key);
    if (val != .string) return error.InvalidFieldType;
    return val.string;
}

pub fn getInt(table: *Table, row: *Row, field_name: []const u8) !i64 {
    const v = getFieldValueByName(table, row, field_name) orelse
        return error.FieldNotFound;

    return switch (v.*) {
        .Int => |n| n,
        else => error.UnexpectedType,
    };
}

pub fn getFloat(table: *Table, row: *Row, field_name: []const u8) !f64 {
    const v = getFieldValueByName(table, row, field_name) orelse
        return error.FieldNotFound;

    return switch (v.*) {
        .Float => |f| f,
        .Int => |i| @floatFromInt(i),
        else => error.UnexpectedType,
    };
}

pub fn getBool(table: *Table, row: *Row, field_name: []const u8) !bool {
    const v = getFieldValueByName(table, row, field_name) orelse
        return error.FieldNotFound;

    return switch (v.*) {
        .Bool => |b| b,
        else => error.UnexpectedType,
    };
}

pub fn getString(table: *Table, row: *Row, field_name: []const u8) ![]const u8 {
    const v = getFieldValueByName(table, row, field_name) orelse
        return error.FieldNotFound;

    return switch (v.*) {
        .String => |s| s,
        .Enum => |s| s,
        .Ref => |s| s,
        else => error.UnexpectedType,
    };
}

pub fn getList(table: *Table, row: *Row, field_name: []const u8) ![]const Value {
    const v = getFieldValueByName(table, row, field_name) orelse
        return error.FieldNotFound;

    return switch (v.*) {
        .List => |list| list,
        else => error.UnexpectedType,
    };
}

fn parseFields(
    allocator: std.mem.Allocator,
    fields_val: std.json.Value,
) ![]FieldDef {
    const obj = switch (fields_val) {
        .object => |o| o,
        else => return error.InvalidFieldsObject,
    };

    var list = std.ArrayList(FieldDef).init(allocator);
    errdefer list.deinit();

    var it = obj.iterator();
    while (it.next()) |entry| {
        const field_name = entry.key_ptr.*;
        const def_val = entry.value_ptr.*;

        const def_obj = switch (def_val) {
            .object => |o| o,
            else => return error.InvalidFieldDef,
        };

        const type_name = try getStringField(def_obj, "type");
        const field_type = try parseFieldType(type_name);

        var fd = FieldDef{
            .name = try dupString(allocator, field_name),
            .field_type = field_type,
            .enum_name = null,
            .ref_table = null,
            .list_element_type = null,
        };

        switch (field_type) {
            .Enum => {
                fd.enum_name = try dupString(allocator, try getStringField(def_obj, "enum"));
            },
            .Ref => {
                fd.ref_table = try dupString(allocator, try getStringField(def_obj, "table"));
            },
            .List => {
                const elem_type_name = try getStringField(def_obj, "element_type");
                const elem_type = try parseListElementType(elem_type_name);
                fd.list_element_type = elem_type;

                if (elem_type == .Ref) {
                    fd.ref_table = try dupString(allocator, try getStringField(def_obj, "table"));
                }
            },
            else => {},
        }

        try list.append(fd);
    }

    return try list.toOwnedSlice();
}

fn parseRows(
    allocator: std.mem.Allocator,
    fields: []const FieldDef,
    rows_val: std.json.Value,
) ![]Row {
    const obj = switch (rows_val) {
        .object => |o| o,
        else => return error.InvalidRowsObject,
    };

    var list = std.ArrayList(Row).init(allocator);
    errdefer {
        for (list.items) |*r| deinitRow(r, allocator);
        list.deinit();
    }

    var it = obj.iterator();
    while (it.next()) |entry| {
        const row_key = entry.key_ptr.*;
        const row_val = entry.value_ptr.*;
        const row_obj = switch (row_val) {
            .object => |o| o,
            else => return error.InvalidRowValue,
        };

        // build values aligned with fields[]
        var values = try std.ArrayList(Value).initCapacity(allocator, fields.len);
        errdefer {
            for (values.items) |*v| deinitValue(v, allocator);
            values.deinit();
        }

        for (fields) |field_def| {
            const fv = try getField(row_obj, field_def.name);
            const v = try parseValueForField(allocator, &field_def, fv);
            try values.append(v);
        }

        const row = Row{
            .key = try dupString(allocator, row_key),
            .values = try values.toOwnedSlice(),
        };
        try list.append(row);
    }

    return try list.toOwnedSlice();
}

fn parseValue(allocator: std.mem.Allocator, val: std.json.Value) !Value {
    return switch (val) {
        .integer => |i| .{ .Int = i },
        .float => |f| .{ .Float = f },
        .bool => |b| .{ .Bool = b },
        .string => |s| .{ .String = try dupString(allocator, s) },
        else => .{ .Json = val },
    };
}

fn parseListValue(allocator: std.mem.Allocator, field_def: *const FieldDef, val: std.json.Value) !Value {
    if (val != .array) return error.TypeMismatch;
    const arr = val.array;
    var list = try std.ArrayList(Value).initCapacity(allocator, arr.items.len);
    errdefer {
        for (list.items) |*v| deinitValue(v, allocator);
        list.deinit();
    }
    for (arr.items) |item| {
        const elem_val = try parseListElement(allocator, field_def, item);
        try list.append(elem_val);
    }
    return .{ .List = try list.toOwnedSlice() };
}

fn parseListElement(allocator: std.mem.Allocator, field_def: *const FieldDef, val: std.json.Value) !Value {
    const elem_type = field_def.list_element_type orelse return error.MissingListElementType;
    return switch (elem_type) {
        .Int => if (val == .integer) .{ .Int = val.integer } else error.TypeMismatch,
        .Float => if (val == .float) .{ .Float = val.float } else error.TypeMismatch,
        .Bool => if (val == .bool) .{ .Bool = val.bool } else error.TypeMismatch,
        .String => if (val == .string) .{ .String = try dupString(allocator, val.string) } else error.TypeMismatch,
        .Enum => if (val == .string) .{ .Enum = try dupString(allocator, val.string) } else error.TypeMismatch,
        .Ref => if (val == .string) .{ .Ref = try dupString(allocator, val.string) } else error.TypeMismatch,
        .Json => .{ .Json = val },
    };
}

fn parseFieldType(type_name: []const u8) !FieldType {
    if (std.mem.eql(u8, type_name, "Int")) return .Int;
    if (std.mem.eql(u8, type_name, "Float")) return .Float;
    if (std.mem.eql(u8, type_name, "Bool")) return .Bool;
    if (std.mem.eql(u8, type_name, "String")) return .String;
    if (std.mem.eql(u8, type_name, "Enum")) return .Enum;
    if (std.mem.eql(u8, type_name, "Ref")) return .Ref;
    if (std.mem.eql(u8, type_name, "List")) return .List;
    if (std.mem.eql(u8, type_name, "Json")) return .Json;
    return error.UnknownFieldType;
}

fn parseListElementType(type_name: []const u8) !ListElementType {
    if (std.mem.eql(u8, type_name, "Int")) return .Int;
    if (std.mem.eql(u8, type_name, "Float")) return .Float;
    if (std.mem.eql(u8, type_name, "Bool")) return .Bool;
    if (std.mem.eql(u8, type_name, "String")) return .String;
    if (std.mem.eql(u8, type_name, "Enum")) return .Enum;
    if (std.mem.eql(u8, type_name, "Ref")) return .Ref;
    if (std.mem.eql(u8, type_name, "Json")) return .Json;
    return error.UnknownListElementType;
}

fn parseListElementValue(
    allocator: std.mem.Allocator,
    elem_type: ListElementType,
    field_def: *const FieldDef, // we might use ref_table later, but no comptime stuff here
    json_val: json.Value,
) !Value {
    switch (elem_type) {
        .Int => switch (json_val) {
            .integer => |i| return Value{ .Int = i },
            .float => |f| return Value{ .Int = @intFromFloat(f) },
            else => return error.ExpectedInteger,
        },
        .Float => switch (json_val) {
            .float => |f| return Value{ .Float = f },
            .integer => |i| return Value{ .Float = @floatFromInt(i) },
            else => return error.ExpectedFloat,
        },
        .Bool => switch (json_val) {
            .bool => |b| return Value{ .Bool = b },
            else => return error.ExpectedBool,
        },
        .String => switch (json_val) {
            .string => |s| {
                const dup = try dupString(allocator, s);
                return Value{ .String = dup };
            },
            else => return error.ExpectedString,
        },
        .Enum => switch (json_val) {
            .string => |s| {
                const dup = try dupString(allocator, s);
                return Value{ .Enum = dup };
            },
            else => return error.ExpectedEnumString,
        },
        .Ref => switch (json_val) {
            .string => |s| {
                // We don’t validate against ref_table here yet; that’s for a later validateRefs() pass.
                if (field_def.ref_table == null) return error.MissingRefTableInFieldDef;
                const dup = try dupString(allocator, s);
                return Value{ .Ref = dup };
            },
            else => return error.ExpectedRefString,
        },
        .Json => {
            // raw JSON node; lifetime handled by the json allocator / parse_result.deinit()
            return Value{ .Json = json_val };
        },
    }
}

fn parseValueForField(
    allocator: std.mem.Allocator,
    field_def: *const FieldDef,
    json_val: json.Value,
) !Value {
    switch (field_def.field_type) {
        .Int => switch (json_val) {
            .integer => |i| return Value{ .Int = i },
            .float => |f| return Value{ .Int = @intFromFloat(f) },
            else => return error.ExpectedInteger,
        },
        .Float => switch (json_val) {
            .float => |f| return Value{ .Float = f },
            .integer => |i| return Value{ .Float = @floatFromInt(i) },
            else => return error.ExpectedFloat,
        },
        .Bool => switch (json_val) {
            .bool => |b| return Value{ .Bool = b },
            else => return error.ExpectedBool,
        },
        .String => switch (json_val) {
            .string => |s| {
                const dup = try dupString(allocator, s);
                return Value{ .String = dup };
            },
            else => return error.ExpectedString,
        },
        .Enum => switch (json_val) {
            .string => |s| {
                const dup = try dupString(allocator, s);
                return Value{ .Enum = dup };
            },
            else => return error.ExpectedEnumString,
        },
        .Ref => switch (json_val) {
            .string => |s| {
                const dup = try dupString(allocator, s);
                return Value{ .Ref = dup };
            },
            else => return error.ExpectedRefString,
        },
        .Json => {
            // Just keep the raw node.
            return Value{ .Json = json_val };
        },
        .List => {
            if (field_def.list_element_type == null) {
                return error.MissingListElementType;
            }
            const elem_type = field_def.list_element_type.?;

            const arr = switch (json_val) {
                .array => |a| a,
                else => return error.ExpectedArrayForList,
            };

            var list = std.ArrayList(Value).init(allocator);
            errdefer {
                for (list.items) |*v| deinitValue(v, allocator);
                list.deinit();
            }

            for (arr.items) |elem| {
                const v = try parseListElementValue(allocator, elem_type, field_def, elem);
                try list.append(v);
            }

            const slice = try list.toOwnedSlice();
            return Value{ .List = slice };
        },
    }
}

fn fieldTypeToString(ft: FieldType) []const u8 {
    return switch (ft) {
        .Int => "Int",
        .Float => "Float",
        .Bool => "Bool",
        .String => "String",
        .Enum => "Enum",
        .Ref => "Ref",
        .List => "List",
        .Json => "Json",
    };
}

fn listElementTypeToString(et: ListElementType) []const u8 {
    return switch (et) {
        .Int => "Int",
        .Float => "Float",
        .Bool => "Bool",
        .String => "String",
        .Enum => "Enum",
        .Ref => "Ref",
        .Json => "Json",
    };
}

fn writeJsonString(writer: anytype, s: []const u8) !void {
    try writer.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => {
                try writer.writeAll("\\\"");
            },
            '\\' => {
                try writer.writeAll("\\\\");
            },
            else => {
                try writer.writeByte(c);
            },
        }
    }
    try writer.writeByte('"');
}

fn writeValueJson(writer: anytype, v: *const Value) !void {
    switch (v.*) {
        .Int => |n| try std.fmt.format(writer, "{d}", .{n}),
        .Float => |f| try std.fmt.format(writer, "{d}", .{f}),
        .Bool => |b| try std.fmt.format(writer, "{}", .{b}),
        .String => |s| try writeJsonString(writer, s),
        .Enum => |s| try writeJsonString(writer, s),
        .Ref => |s| try writeJsonString(writer, s),
        .List => |list| {
            try writer.writeByte('[');
            for (list, 0..) |*elem, i| {
                if (i != 0) try writer.writeAll(", ");
                try writeValueJson(writer, elem);
            }
            try writer.writeByte(']');
        },
        .Json => {
            // For now, just write null (you can improve later to serialize actual JSON)
            try writer.writeAll("null");
        },
    }
}

pub fn saveTableToFile(
    table: *const Table,
    allocator: std.mem.Allocator,
    dir_path: []const u8,
) !void {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = false });
    defer dir.close();

    const file_name = try std.mem.concat(allocator, u8, &.{ table.name, ".zdb.json" });
    defer allocator.free(file_name);

    var file = try dir.createFile(file_name, .{ .truncate = true });
    defer file.close();

    var writer = file.writer();

    try writer.writeAll("{\n");

    // "table"
    try writer.writeAll("  \"table\": ");
    try writeJsonString(writer, table.name);
    try writer.writeAll(",\n");

    // "fields"
    try writer.writeAll("  \"fields\": {\n");
    for (table.fields, 0..) |f, i| {
        try writer.writeAll("    ");
        try writeJsonString(writer, f.name);
        try writer.writeAll(": { \"type\": ");
        try writeJsonString(writer, fieldTypeToString(f.field_type));

        switch (f.field_type) {
            .Enum => if (f.enum_name) |e| {
                try writer.writeAll(", \"enum\": ");
                try writeJsonString(writer, e);
            },
            .Ref => if (f.ref_table) |t| {
                try writer.writeAll(", \"table\": ");
                try writeJsonString(writer, t);
            },
            .List => {
                if (f.list_element_type) |et| {
                    try writer.writeAll(", \"element_type\": ");
                    try writeJsonString(writer, listElementTypeToString(et));
                }
                if (f.list_element_type == .Ref and f.ref_table) |t| {
                    try writer.writeAll(", \"table\": ");
                    try writeJsonString(writer, t);
                }
            },
            else => {},
        }

        try writer.writeAll(" }");
        if (i + 1 < table.fields.len) try writer.writeAll(",");
        try writer.writeAll("\n");
    }
    try writer.writeAll("  },\n");

    // "rows"
    try writer.writeAll("  \"rows\": {\n");
    for (table.rows, 0..) |r, ri| {
        try writer.writeAll("    ");
        try writeJsonString(writer, r.key);
        try writer.writeAll(": {");

        for (table.fields, 0..) |f, fi| {
            if (fi == 0) {
                try writer.writeAll(" ");
            } else {
                try writer.writeAll(", ");
            }

            try writeJsonString(writer, f.name);
            try writer.writeAll(": ");
            try writeValueJson(writer, &r.values[fi]);
        }

        try writer.writeAll(" }");
        if (ri + 1 < table.rows.len) try writer.writeAll(",");
        try writer.writeAll("\n");
    }
    try writer.writeAll("  }\n}\n");
}

fn deinitValue(v: *Value, allocator: std.mem.Allocator) void {
    switch (v.*) {
        .String, .Enum, .Ref => |s| allocator.free(s),
        .List => |list| {
            for (list) |*elem| deinitValue(elem, allocator);
            allocator.free(list);
        },
        .Json => |node| {
            //TODO: node was allocated with json_allocator, so you might
            // need a different strategy here depending on your design
            _ = node;
        },
        else => {},
    }
}

fn deinitRow(row: *Row, allocator: std.mem.Allocator) void {
    allocator.free(row.key);
    for (row.values) |*v| deinitValue(v, allocator);
    allocator.free(row.values);
}

fn deinitTable(table: *Table, allocator: std.mem.Allocator) void {
    allocator.free(table.name);

    for (table.fields) |f| {
        allocator.free(f.name);
        if (f.enum_name) |e| allocator.free(e);
        if (f.ref_table) |t| allocator.free(t);
    }
    allocator.free(table.fields);

    for (table.rows) |*r| {
        deinitRow(r, allocator);
    }
    allocator.free(table.rows);
}

pub fn deinit(db: *Database, allocator: std.mem.Allocator) void {
    for (db.tables) |*t| deinitTable(t, allocator);
    allocator.free(db.tables);
}

fn validateDatabase(db: *Database, options: LoadOptions) !void {
    if (options.validate_refs) {
        try validateRefs(db);
    }
    if (options.validate_enums) {
        try validateEnums(db);
    }
}

fn validateEnums(db: *Database) !void {
    _ = db;
    //TODO: Later: check that Enum string values match a known set for each enum_name.
}

fn validateRefs(db: *Database) !void {
    // For each table
    for (db.tables) |*table| {
        // For each field that is a Ref or List<Ref>
        for (table.fields, 0..) |field_def, field_index| {
            const is_ref = field_def.field_type == .Ref;
            const is_list_ref = field_def.field_type == .List and
                field_def.list_element_type != null and
                field_def.list_element_type.? == .Ref;

            if (!is_ref and !is_list_ref) continue;

            const target_table_name = field_def.ref_table orelse
                return error.MissingRefTableName;

            const target_table = getTable(db, target_table_name) orelse
                return error.UnknownRefTable;

            // For each row in this table
            for (table.rows) |*row| {
                const v = &row.values[field_index];

                if (is_ref) {
                    switch (v.*) {
                        .Ref => |s| {
                            if (!rowExists(target_table, s)) {
                                return error.InvalidRef;
                            }
                        },
                        else => return error.UnexpectedTypeForRef,
                    }
                } else if (is_list_ref) {
                    switch (v.*) {
                        .List => |list| {
                            for (list) |elem| {
                                switch (elem) {
                                    .Ref => |s| {
                                        if (!rowExists(target_table, s)) {
                                            return error.InvalidRef;
                                        }
                                    },
                                    else => return error.UnexpectedTypeForRef,
                                }
                            }
                        },
                        else => return error.UnexpectedTypeForRef,
                    }
                }
            }
        }
    }
}

fn rowExists(table: *Table, key: []const u8) bool {
    for (table.rows) |row| {
        if (std.mem.eql(u8, row.key, key)) return true;
    }
    return false;
}
