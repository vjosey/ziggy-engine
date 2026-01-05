const std = @import("std");

pub fn build(b: *std.Build) void {
    const core_dep = b.dependency("ziggy_core", .{});

    const mod = b.addModule("ldtk", .{
        .root_source_file = b.path("compile.zig"),
    });

    mod.addImport("ziggy_core", core_dep.module("ziggy_core"));
}
