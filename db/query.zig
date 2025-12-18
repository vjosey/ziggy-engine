const std = @import("std");
const json = std.json;
const types = @import("types.zig");

const Database = types.Database;
const Table = types.Table;
const Row = types.Row;
const FieldDef = types.FieldDef;
const Value = types.Value;
const ListElementType = types.ListElementType;
const FieldType = types.FieldType;

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

pub fn dupString(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    return try allocator.dupe(u8, s);
}

pub fn getField(obj: std.json.ObjectMap, key: []const u8) !std.json.Value {
    if (obj.get(key)) |val| {
        return val;
    }
    return error.MissingField;
}

pub fn getStringField(obj: std.json.ObjectMap, key: []const u8) ![]const u8 {
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

pub fn cloneValue(src: Value, allocator: std.mem.Allocator) !Value {
    return switch (src) {
        .Int => |x| Value{ .Int = x },
        .Float => |x| Value{ .Float = x },
        .Bool => |x| Value{ .Bool = x },

        // Adjust / add cases to match your actual Value tags:
        .String => |s| Value{ .String = try allocator.dupe(u8, s) },
        .Enum => |s| Value{ .Enum = try allocator.dupe(u8, s) },
        .Ref => |s| Value{ .Ref = try allocator.dupe(u8, s) },

        .List => |list| blk: {
            // Deep-copy the list of values
            if (list.len == 0) break :blk Value{ .List = list };

            var out = try allocator.alloc(Value, list.len);
            errdefer allocator.free(out);

            for (list, 0..) |elem, i| {
                out[i] = try cloneValue(elem, allocator);
            }

            break :blk Value{ .List = out };
        },

        // If you have a Json/raw-string variant:
        .Json => |bytes| Value{ .Json = try allocator.dupe(u8, bytes) },

        // If you have .Null or similar:
        //.Null => Value{ .Null = {} },
    };
}
