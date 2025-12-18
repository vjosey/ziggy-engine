const std = @import("std");
const json = std.json;
const types = @import("types.zig");
const deinit = @import("deinit.zig");
const query = @import("query.zig");

const Database = types.Database;
const Table = types.Table;
const Row = types.Row;
const FieldDef = types.FieldDef;
const Value = types.Value;
const LoadOptions = types.LoadOptions;

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

pub fn addTable(db: *Database, allocator: std.mem.Allocator, table: Table) !void {
    const old_len = db.tables.len;
    const new_len = old_len + 1;

    var new = try allocator.alloc(Table, new_len);
    std.mem.copyForwards(Table, new[0..old_len], db.tables);

    new[old_len] = table; // moves ownership into db

    if (db.tables.len > 0) allocator.free(db.tables);
    db.tables = new;
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
    // std.mem.copy(FieldDef, new, table.fields);
    std.mem.copyForwards(FieldDef, new[0..table.fields.len], table.fields);

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

    const old_len = table.rows.len;
    const new_len = old_len + 1;

    // allocate new rows array
    var new_rows = try allocator.alloc(Row, new_len);
    errdefer allocator.free(new_rows);

    // copy existing rows (shallow copy is fine; we are moving ownership of pointers)
    std.mem.copyForwards(Row, new_rows[0..old_len], table.rows);

    // allocate + deep-clone value array
    var vals = try allocator.alloc(Value, values.len);
    errdefer allocator.free(vals);

    // IMPORTANT: if cloneValue allocates, we must free anything cloned so far on failure
    var cloned_count: usize = 0;
    errdefer {
        // deinit only the values we successfully cloned
        for (vals[0..cloned_count]) |*v| deinit.deinitValue(v, allocator);
    }

    for (values, 0..) |v, i| {
        vals[i] = try query.cloneValue(v, allocator);
        cloned_count += 1;
    }

    // clone key
    const key_copy = try allocator.dupe(u8, key);
    errdefer allocator.free(key_copy);

    // assign new row
    new_rows[old_len] = .{
        .key = key_copy,
        .values = vals,
    };

    // free old rows array storage (not the rows’ internal memory)
    if (old_len > 0) allocator.free(table.rows);

    // commit
    table.rows = new_rows;

    // NOTE:
    // Do NOT free(vals) or free(key_copy) here; ownership is now in table.rows[old_len].
}
