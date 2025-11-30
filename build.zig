const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //
    // ────────────────────────────────────────────────
    // Ziggy Core as a module
    // ────────────────────────────────────────────────
    //
    const ziggy_core_mod = b.addModule("ziggy_core", .{
        .root_source_file = b.path("core/ziggy_core.zig"),
    });

    //
    // ────────────────────────────────────────────────
    // 1. Ziggy Studio (editor executable)
    // ────────────────────────────────────────────────
    //
    const ziggy_studio = b.addExecutable(.{
        .name = "ziggy_studio",
        .root_source_file = b.path("studio/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    ziggy_studio.root_module.addImport("ziggy_core", ziggy_core_mod);
    b.installArtifact(ziggy_studio);

    const run_studio = b.addRunArtifact(ziggy_studio);
    if (b.args) |args| run_studio.addArgs(args);
    b.step("run-studio", "Run Ziggy Studio").dependOn(&run_studio.step);

    //
    // ────────────────────────────────────────────────
    // 2. Example: hello_core
    // ────────────────────────────────────────────────
    //
    const hello_core = b.addExecutable(.{
        .name = "hello_core",
        .root_source_file = b.path("examples/hello_core/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    hello_core.root_module.addImport("ziggy_core", ziggy_core_mod);
    b.installArtifact(hello_core);

    const run_hello = b.addRunArtifact(hello_core);
    if (b.args) |args| run_hello.addArgs(args);
    b.step("run-example", "Run hello_core example").dependOn(&run_hello.step);
}
