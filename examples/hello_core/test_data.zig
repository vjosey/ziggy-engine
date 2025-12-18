const std = @import("std");
const ziggy_core = @import("ziggy_core");
const zdb = @import("ziggy_db");
const log = ziggy_core.support.log;

pub fn addEnemyWithStats(
    enemies: *zdb.Table,
    allocator: std.mem.Allocator,
    key: []const u8,
    display_name: []const u8,
    hp_value: i64,
    speed_value: i64,
) !void {
    const Value = zdb.Value;

    // Allocate one Value per field
    var values = try allocator.alloc(Value, enemies.fields.len);
    defer allocator.free(values);

    for (enemies.fields, 0..) |field_def, i| {
        const field_name = field_def.name;
        const field_type = field_def.field_type;

        // Fill special fields by name if they exist
        if (std.mem.eql(u8, field_name, "hp")) {
            values[i] = Value{ .Int = hp_value };
            continue;
        } else if (std.mem.eql(u8, field_name, "speed")) {
            values[i] = Value{ .Int = speed_value };
            continue;
        } else if (std.mem.eql(u8, field_name, "name")) {
            const name_copy = try allocator.dupe(u8, display_name);
            values[i] = Value{ .String = name_copy };
            continue;
        }

        // Everything else: default based on type
        switch (field_type) {
            .Int => {
                values[i] = Value{ .Int = 0 };
            },
            .Float => {
                values[i] = Value{ .Float = 0.0 };
            },
            .Bool => {
                values[i] = Value{ .Bool = false };
            },
            .String, .Enum, .Ref => {
                // Empty string literal is fine; it's static memory
                values[i] = Value{ .String = "" };
            },
            .List => {
                // Empty list of values
                const empty = try allocator.alloc(Value, 0);
                values[i] = Value{ .List = empty };
            },
            .Json => {
                // Represent "no meta" as null JSON
                const json_val = std.json.Value{ .null = {} };
                const json_text = try std.json.stringifyAlloc(allocator, json_val, .{ .whitespace = .indent_2 });
                errdefer allocator.free(json_text);
                values[i] = Value{ .Json = json_text };
            },
        }
    }

    try zdb.addRow(enemies, allocator, key, values);
}

pub fn addExtraEnemiesAndSave(allocator: std.mem.Allocator) !void {
    const options = zdb.LoadOptions{
        .verbose = true,
        .validate_refs = false,
        .validate_enums = false,
    };

    var db = try zdb.loadFromDir(allocator, "examples/hello_core/data", options);
    defer zdb.deinit(&db, allocator);

    const enemies = try ensureEnemiesTable(&db, allocator);

    try addEnemyWithStats(enemies, allocator, "brute", "Brute", 80, 4);
    try addEnemyWithStats(enemies, allocator, "ghoul", "Ghoul", 60, 6);
    try addEnemyWithStats(enemies, allocator, "spitter", "Spitter", 40, 5);
    try addEnemyWithStats(enemies, allocator, "tank", "Tank", 150, 2);
    try addEnemyWithStats(enemies, allocator, "crawler", "Crawler", 25, 3);
    try addEnemyWithStats(enemies, allocator, "witch", "Witch", 50, 7);
    try addEnemyWithStats(enemies, allocator, "shadow", "Shadow", 35, 9);
    try addEnemyWithStats(enemies, allocator, "stalker", "Stalker", 55, 8);
    try addEnemyWithStats(enemies, allocator, "overlord", "Overlord", 200, 1);
    try addEnemyWithStats(enemies, allocator, "swarmling", "Swarmling", 15, 10);

    try zdb.saveTableToFile(enemies, allocator, "examples/hello_core/data");
    log.info("Added 10 extra enemies and saved enemies.zdb.json\n", .{});
}

fn ensureEnemiesTable(db: *zdb.Database, allocator: std.mem.Allocator) !*zdb.Table {
    if (zdb.getTable(db, "enemies")) |t| return t;

    // Create new table (minimal functional schema)
    var table = try zdb.createTable(allocator, "enemies");
    errdefer zdb.deinitTable(&table, allocator);

    // Keep it minimal + practical: name + stats
    try zdb.addField(&table, allocator, .{ .name = "name", .field_type = .String });
    try zdb.addField(&table, allocator, .{ .name = "hp", .field_type = .Int });
    try zdb.addField(&table, allocator, .{ .name = "speed", .field_type = .Int });

    // Add the table into the DB (you may already have a helper — if so, use it)
    try zdb.addTable(db, allocator, table);

    // After addTable, db owns it — don’t deinitTable(table) here.
    return zdb.getTable(db, "enemies").?;
}

pub fn buildWeaponsTable(allocator: std.mem.Allocator) !zdb.Table {
    const Value = zdb.Value;

    var table = try zdb.createTable(allocator, "weapons");

    // Fields: name, damage, range, is_ranged
    try zdb.addField(&table, allocator, .{
        .name = "name",
        .field_type = .String,
        .enum_name = null,
        .ref_table = null,
        .list_element_type = null,
    });
    try zdb.addField(&table, allocator, .{
        .name = "damage",
        .field_type = .Int,
        .enum_name = null,
        .ref_table = null,
        .list_element_type = null,
    });
    try zdb.addField(&table, allocator, .{
        .name = "range",
        .field_type = .Int,
        .enum_name = null,
        .ref_table = null,
        .list_element_type = null,
    });
    try zdb.addField(&table, allocator, .{
        .name = "is_ranged",
        .field_type = .Bool,
        .enum_name = null,
        .ref_table = null,
        .list_element_type = null,
    });

    // Weapon: sword
    const sword_name = try allocator.dupe(u8, "Sword");
    try zdb.addRow(&table, allocator, "sword", &[_]Value{
        Value{ .String = sword_name },
        Value{ .Int = 15 },
        Value{ .Int = 1 },
        Value{ .Bool = false },
    });

    // Weapon: bow
    const bow_name = try allocator.dupe(u8, "Bow");
    try zdb.addRow(&table, allocator, "bow", &[_]Value{
        Value{ .String = bow_name },
        Value{ .Int = 10 },
        Value{ .Int = 6 },
        Value{ .Bool = true },
    });

    // Weapon: staff
    const staff_name = try allocator.dupe(u8, "Staff");
    try zdb.addRow(&table, allocator, "staff", &[_]Value{
        Value{ .String = staff_name },
        Value{ .Int = 8 },
        Value{ .Int = 4 },
        Value{ .Bool = true },
    });

    return table;
}

pub fn createWeaponsTableAndSave(allocator: std.mem.Allocator) !void {
    var weapons = try buildWeaponsTable(allocator);
    defer zdb.deinitTable(&weapons, allocator);
    // Optional: later you can add it to a Database; for now we only care about saving
    defer {
        // You can add a small deinitTable here if you expose it.
    }

    try zdb.saveTableToFile(&weapons, allocator, "examples/hello_core/data");
    log.info("Created weapons.zdb.json\n", .{});
}

pub fn buildItemsTable(allocator: std.mem.Allocator) !zdb.Table {
    const Value = zdb.Value;

    var table = try zdb.createTable(allocator, "items");

    // Fields: name, kind, power, is_consumable
    try zdb.addField(&table, allocator, .{
        .name = "name",
        .field_type = .String,
        .enum_name = null,
        .ref_table = null,
        .list_element_type = null,
    });
    try zdb.addField(&table, allocator, .{
        .name = "kind",
        .field_type = .String, // later you can turn this into Enum
        .enum_name = null,
        .ref_table = null,
        .list_element_type = null,
    });
    try zdb.addField(&table, allocator, .{
        .name = "power",
        .field_type = .Int,
        .enum_name = null,
        .ref_table = null,
        .list_element_type = null,
    });
    try zdb.addField(&table, allocator, .{
        .name = "is_consumable",
        .field_type = .Bool,
        .enum_name = null,
        .ref_table = null,
        .list_element_type = null,
    });

    // Health potion
    const hp_name = try allocator.dupe(u8, "Health Potion");
    try zdb.addRow(&table, allocator, "health_potion", &[_]Value{
        Value{ .String = hp_name },
        Value{ .String = "consumable" },
        Value{ .Int = 50 },
        Value{ .Bool = true },
    });

    // Mana potion
    const mp_name = try allocator.dupe(u8, "Mana Potion");
    try zdb.addRow(&table, allocator, "mana_potion", &[_]Value{
        Value{ .String = mp_name },
        Value{ .String = "consumable" },
        Value{ .Int = 40 },
        Value{ .Bool = true },
    });

    // Strength amulet
    const amulet_name = try allocator.dupe(u8, "Amulet of Strength");
    try zdb.addRow(&table, allocator, "strength_amulet", &[_]Value{
        Value{ .String = amulet_name },
        Value{ .String = "equipment" },
        Value{ .Int = 10 },
        Value{ .Bool = false },
    });

    return table;
}

pub fn createItemsTableAndSave(allocator: std.mem.Allocator) !void {
    var items = try buildItemsTable(allocator);
    // Optional deinit similar to weapons
    defer zdb.deinitTable(&items, allocator);
    try zdb.saveTableToFile(&items, allocator, "examples/hello_core/data");
    log.info("Created items.zdb.json\n", .{});
}
