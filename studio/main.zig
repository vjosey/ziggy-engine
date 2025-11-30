const std = @import("std");
const ziggy_core = @import("ziggy_core");

pub fn main() !void {
    std.debug.print("Ziggy Studio stub running.\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Use the runtime from core
    const runtime_mod = ziggy_core.runtime;

    var rt = try runtime_mod.ZiggyRuntime.init(allocator);
    defer rt.deinit();

    const scene = &rt.scene;
    const comps = ziggy_core.zcs.components;

    const e = try scene.createEntity("EditorTest");
    try scene.addTransform(e, comps.Transform{});

    std.debug.print("Created entity {d} in studio runtime.\n", .{e});
}
