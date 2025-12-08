const std = @import("std");
const ziggy_core = @import("ziggy_core");
const zdb = @import("ziggy_db");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const runtime_mod = ziggy_core.runtime;
    const comps = ziggy_core.zcs.components;
    const log = ziggy_core.support.log;

    try dataConnection(allocator);

    //runtime setup
    var rt = try runtime_mod.ZiggyRuntime.init(allocator);
    defer rt.deinit();

    const scene = &rt.scene;

    // Player
    const player = try scene.createEntity("Player");
    try scene.addTransform(player, comps.Transform{
        .position = .{ 0.0, 0.0, 0.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .scale = .{ 1.0, 1.0, 1.0 },
    });
    try scene.addVelocity(player, comps.Velocity{ .value = .{ 1.0, 0.0, 0.0 } });

    // Camera looking at the player
    const cam_ent = try scene.createEntity("MainCamera");
    try scene.addTransform(cam_ent, comps.Transform{
        .position = .{ 0.0, 5.0, 10.0 }, // above and behind
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .scale = .{ 1.0, 1.0, 1.0 },
    });
    try scene.addCamera(cam_ent, comps.Camera{
        .fov_y = std.math.degreesToRadians(60.0),
        .near = 0.1,
        .far = 200.0,
        .aspect = 16.0 / 9.0,
        .target = .{ 0.0, 0.0, 0.0 }, // look at origin (where player starts)
        .up = .{ 0.0, 1.0, 0.0 },
    });

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        rt.update();

        if (scene.getTransform(cam_ent)) |t_cam| {
            const wx = t_cam.world_matrix[12];
            const wy = t_cam.world_matrix[13];
            const wz = t_cam.world_matrix[14];

            log.info(
                "Frame {d}: cam world pos = ({d:.3}, {d:.3}, {d:.3})",
                .{ i, wx, wy, wz },
            );
        }

        std.time.sleep(16_666_667);
    }
}

fn dataConnection(allocator: std.mem.Allocator) !void {
    // ----- load database from the example data folder -----
    const options = zdb.LoadOptions{
        .verbose = true, // see what it's loading
        .validate_refs = false, // no refs yet
        .validate_enums = false, // no enums yet
    };

    // when running from project root via `zig build run-example`,
    // this path is relative to the root:
    var db = try zdb.loadFromDir(allocator, "examples/hello_core/data", options);
    defer zdb.deinit(&db, allocator);

    const stdout = std.io.getStdOut().writer();

    // ----- get the "enemies" table -----
    const enemies = zdb.getTable(&db, "enemies") orelse {
        try stdout.print("No 'enemies' table found!\n", .{});
        return;
    };

    try stdout.print("Loaded table: {s}\n", .{enemies.name});
    try stdout.print("Fields:\n", .{});

    for (enemies.fields, 0..) |field, i| {
        try stdout.print("  {d}: {s}\n", .{ i, field.name });
    }

    // ----- print all rows -----
    try stdout.print("\nRows:\n", .{});
    for (enemies.rows) |row| {
        try stdout.print("  key={s}", .{row.key});

        // find and print hp + name using helper
        if (zdb.getFieldValueByName(enemies, &row, "hp")) |v_hp| {
            switch (v_hp.*) {
                .Int => |hp| try stdout.print(", hp={d}", .{hp}),
                else => try stdout.print(", hp=<not Int>", .{}),
            }
        }

        if (zdb.getFieldValueByName(enemies, &row, "name")) |v_name| {
            switch (v_name.*) {
                .String => |name| try stdout.print(", name={s}", .{name}),
                else => try stdout.print(", name=<not String>", .{}),
            }
        }

        try stdout.print("\n", .{});
    }

    // ----- direct lookup: "zombie" row -----
    try stdout.print("\nLooking up 'zombie'...\n", .{});

    const zombie = zdb.getRow(enemies, "zombie") orelse {
        try stdout.print("No 'zombie' row found!\n", .{});
        return;
    };

    if (zdb.getFieldValueByName(enemies, zombie, "hp")) |v| {
        switch (v.*) {
            .Int => |hp| try stdout.print("Zombie HP: {d}\n", .{hp}),
            else => try stdout.print("Zombie hp is not an Int\n", .{}),
        }
    } else {
        try stdout.print("Zombie has no hp field\n", .{});
    }
}
