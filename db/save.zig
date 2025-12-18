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

                    if (et == .Ref) {
                        if (f.ref_table) |t| {
                            try writer.writeAll(", \"table\": ");
                            try writeJsonString(writer, t);
                        }
                    }
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
