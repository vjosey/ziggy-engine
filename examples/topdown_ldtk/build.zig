const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "topdown_ldtk",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const core_dep = b.dependency("core", .{});
    exe.root_module.addImport("core", core_dep.module("ziggy_core"));

    const ldtk_dep = b.dependency("ldtk", .{});
    exe.root_module.addImport("ldtk", ldtk_dep.module("ldtk"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "Run the sample").dependOn(&run_cmd.step);
}
