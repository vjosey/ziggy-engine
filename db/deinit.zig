const std = @import("std");
const json = std.json;
const types = @import("types.zig");

const Database = types.Database;
const Table = types.Table;
const Row = types.Row;
const Value = types.Value;

pub fn deinitValue(v: *Value, allocator: std.mem.Allocator) void {
    switch (v.*) {
        .String, .Enum, .Ref => |s| allocator.free(s),
        .List => |list| {
            for (list) |*elem| deinitValue(elem, allocator);
            allocator.free(list);
        },
        .Json => |bytes| allocator.free(bytes),
        else => {},
    }
}

pub fn deinitRow(row: *Row, allocator: std.mem.Allocator) void {
    allocator.free(row.key);
    for (row.values) |*v| deinitValue(v, allocator);
    allocator.free(row.values);
}

pub fn deinitTable(table: *Table, allocator: std.mem.Allocator) void {
    allocator.free(table.name);

    // free fields (and any heap strings inside FieldDef, like field name)
    for (table.fields) |*f| {
        allocator.free(f.name);
        if (f.ref_table) |rt| allocator.free(rt);
        // if you have enum values / list element info that dupes strings, free those too
    }
    if (table.fields.len > 0) allocator.free(table.fields);

    // free rows
    for (table.rows) |*r| deinitRow(r, allocator);
    if (table.rows.len > 0) allocator.free(table.rows);
}

pub fn deinit(db: *Database, allocator: std.mem.Allocator) void {
    for (db.tables) |*t| deinitTable(t, allocator);
    allocator.free(db.tables);
}
