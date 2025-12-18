const std = @import("std");
const json = std.json;
const types = @import("types.zig");
const deinit = @import("deinit.zig");
const query = @import("query.zig");
const validate = @import("validate.zig");

const Database = types.Database;
const Table = types.Table;
const Row = types.Row;
const FieldDef = types.FieldDef;
const Value = types.Value;
const LoadOptions = types.LoadOptions;
const ListElementType = types.ListElementType;
const FieldType = types.FieldType;

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
            deinit.deinitTable(t, allocator);
        }
        tables_list.deinit();
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!validate.hasZdbJsonExtension(entry.name)) continue;

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
        try validate.validateDatabase(&db, options);
    }

    return db;
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
    const table_name = try query.getStringField(root_obj, "table");

    // 5. Get "fields" and build FieldDef[]
    const fields_val = try query.getField(root_obj, "fields");
    const fields = try parseFields(allocator, fields_val);

    // 6. Get "rows" and build Row[]
    const rows_val = try query.getField(root_obj, "rows");
    const rows = try parseRows(allocator, fields, rows_val);

    // 7. Build Table
    return Table{
        .name = try query.dupString(allocator, table_name),
        .fields = fields,
        .rows = rows,
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

        const type_name = try query.getStringField(def_obj, "type");
        const field_type = try parseFieldType(type_name);

        var fd = FieldDef{
            .name = try query.dupString(allocator, field_name),
            .field_type = field_type,
            .enum_name = null,
            .ref_table = null,
            .list_element_type = null,
        };

        switch (field_type) {
            .Enum => {
                fd.enum_name = try query.dupString(allocator, try query.getStringField(def_obj, "enum"));
            },
            .Ref => {
                fd.ref_table = try query.dupString(allocator, try query.getStringField(def_obj, "table"));
            },
            .List => {
                const elem_type_name = try query.getStringField(def_obj, "element_type");
                const elem_type = try parseListElementType(elem_type_name);
                fd.list_element_type = elem_type;

                if (elem_type == .Ref) {
                    fd.ref_table = try query.dupString(allocator, try query.getStringField(def_obj, "table"));
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
        for (list.items) |*r| deinit.deinitRow(r, allocator);
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
            for (values.items) |*v| deinit.deinitValue(v, allocator);
            values.deinit();
        }

        for (fields) |field_def| {
            const fv = try query.getField(row_obj, field_def.name);
            const v = try parseValueForField(allocator, &field_def, fv);
            try values.append(v);
        }

        const row = Row{
            .key = try query.dupString(allocator, row_key),
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
        .string => |s| .{ .String = try query.dupString(allocator, s) },
        else => .{ .Json = val },
    };
}

fn parseListValue(allocator: std.mem.Allocator, field_def: *const FieldDef, val: std.json.Value) !Value {
    if (val != .array) return error.TypeMismatch;
    const arr = val.array;
    var list = try std.ArrayList(Value).initCapacity(allocator, arr.items.len);
    errdefer {
        for (list.items) |*v| deinit.deinitValue(v, allocator);
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
        .String => if (val == .string) .{ .String = try query.dupString(allocator, val.string) } else error.TypeMismatch,
        .Enum => if (val == .string) .{ .Enum = try query.dupString(allocator, val.string) } else error.TypeMismatch,
        .Ref => if (val == .string) .{ .Ref = try query.dupString(allocator, val.string) } else error.TypeMismatch,
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
                const dup = try query.dupString(allocator, s);
                return Value{ .String = dup };
            },
            else => return error.ExpectedString,
        },
        .Enum => switch (json_val) {
            .string => |s| {
                const dup = try query.dupString(allocator, s);
                return Value{ .Enum = dup };
            },
            else => return error.ExpectedEnumString,
        },
        .Ref => switch (json_val) {
            .string => |s| {
                // We don’t validate against ref_table here yet; that’s for a later validateRefs() pass.
                if (field_def.ref_table == null) return error.MissingRefTableInFieldDef;
                const dup = try query.dupString(allocator, s);
                return Value{ .Ref = dup };
            },
            else => return error.ExpectedRefString,
        },
        .Json => {
            // raw JSON node; lifetime handled by the json allocator / parse_result.deinit()
            const json_text = try std.json.stringifyAlloc(allocator, json_val, .{});
            errdefer allocator.free(json_text);
            return Value{ .Json = json_text };
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
                const dup = try query.dupString(allocator, s);
                return Value{ .String = dup };
            },
            else => return error.ExpectedString,
        },
        .Enum => switch (json_val) {
            .string => |s| {
                const dup = try query.dupString(allocator, s);
                return Value{ .Enum = dup };
            },
            else => return error.ExpectedEnumString,
        },
        .Ref => switch (json_val) {
            .string => |s| {
                const dup = try query.dupString(allocator, s);
                return Value{ .Ref = dup };
            },
            else => return error.ExpectedRefString,
        },
        .Json => {
            // Just keep the raw node.
            const json_text = try std.json.stringifyAlloc(allocator, json_val, .{});
            errdefer allocator.free(json_text);
            return Value{ .Json = json_text };
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
                for (list.items) |*v| deinit.deinitValue(v, allocator);
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
