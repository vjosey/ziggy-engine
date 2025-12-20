const std = @import("std");
const core = @import("core");
const ldtk = @import("ldtk").ldtk;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    const log = core.support.log;

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const world = try ldtk.loadWorldFromFile(arena.allocator(), "assets/Typical_TopDown_example.ldtk");
    defer world.deinit(arena.allocator());

    log.info("LDtk jsonVersion: {s}", .{world.json_version});
}
