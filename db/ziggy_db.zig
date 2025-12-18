const std = @import("std");

// Internal modules (same folder)
const types_mod = @import("types.zig");
const load_mod = @import("load.zig");
const query_mod = @import("query.zig");
const build_mod = @import("build.zig");
const save_mod = @import("save.zig");
const validate_mod = @import("validate.zig");
const deinit_mod = @import("deinit.zig");

// Re-export core types
pub const Database = types_mod.Database;
pub const Table = types_mod.Table;
pub const Row = types_mod.Row;
pub const FieldDef = types_mod.FieldDef;
pub const FieldType = types_mod.FieldType;
pub const ListElementType = types_mod.ListElementType;
pub const Value = types_mod.Value;
pub const LoadOptions = types_mod.LoadOptions;

// Re-export functions (public API)
pub const loadFromDir = load_mod.loadFromDir;

pub const getTable = query_mod.getTable;
pub const getRow = query_mod.getRow;
pub const getFieldValueByName = query_mod.getFieldValueByName;
pub const getInt = query_mod.getInt;
pub const getFloat = query_mod.getFloat;
pub const getBool = query_mod.getBool;
pub const getString = query_mod.getString;
pub const getList = query_mod.getList;
pub const getStringField = query_mod.getStringField;
pub const getField = query_mod.getField;

pub const createTable = build_mod.createTable;
pub const addField = build_mod.addField;
pub const addRow = build_mod.addRow;
pub const addTable = build_mod.addTable;

pub const saveTableToFile = save_mod.saveTableToFile;

pub const validateDatabase = validate_mod.validateDatabase;
pub const hasZdbJsonExtension = validate_mod.hasZdbJsonExtension;

// Deinit
pub const deinit = deinit_mod.deinit;
pub const deinitValue = deinit_mod.deinitValue;
pub const deinitTable = deinit_mod.deinitTable;
pub const deinitRow = deinit_mod.deinitRow;
