const std = @import("std");

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
    String: []u8,
    Enum: []u8, // case name, e.g. "Common"
    Ref: []u8, // target row key
    List: []Value, // homogeneous list (you know the element type from FieldDef)
    //Json: std.json.Value, // raw JSON node
    Json: []u8, // raw JSON text (ex: {"a":1} or ["x"])
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
