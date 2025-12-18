const std = @import("std");
const json = std.json;
const types = @import("types.zig");
const query = @import("query.zig");

const Database = types.Database;
const Table = types.Table;
const Row = types.Row;
const FieldDef = types.FieldDef;
const Value = types.Value;
const LoadOptions = types.LoadOptions;

pub fn validateDatabase(db: *Database, options: LoadOptions) !void {
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

            const target_table = query.getTable(db, target_table_name) orelse
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

pub fn rowExists(table: *Table, key: []const u8) bool {
    for (table.rows) |row| {
        if (std.mem.eql(u8, row.key, key)) return true;
    }
    return false;
}

pub fn hasZdbJsonExtension(name: []const u8) bool {
    return std.mem.endsWith(u8, name, ".zdb.json");
}
