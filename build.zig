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
    // ZiggyDB as a standalone module
    // ────────────────────────────────────────────────
    //
    const ziggy_db_mod = b.addModule("ziggy_db", .{
        .root_source_file = b.path("db/ziggy_db.zig"),
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
    ziggy_studio.root_module.addImport("ziggy_db", ziggy_db_mod);
    b.installArtifact(ziggy_studio);

    // 🔗 GLFW + OpenGL – adjust to your paths
    const glfw_path = "C:/Users/Admin/Downloads/glfw-3.4.bin.WIN64";

    // =============================================================================

    // Add GLFW paths
    const include_path = glfw_path ++ "/include";
    const lib_path = glfw_path ++ "/lib-mingw-w64";

    ziggy_studio.addIncludePath(.{ .cwd_relative = include_path });
    ziggy_studio.addLibraryPath(.{ .cwd_relative = lib_path });

    ziggy_studio.linkSystemLibrary("glfw3");
    ziggy_studio.linkSystemLibrary("opengl32");
    ziggy_studio.linkSystemLibrary("gdi32");
    ziggy_studio.linkSystemLibrary("user32");

    const run_studio = b.addRunArtifact(ziggy_studio);
    if (b.args) |args| run_studio.addArgs(args);
    b.step("ziggy-studio", "Run Ziggy Studio").dependOn(&run_studio.step);

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
    hello_core.root_module.addImport("ziggy_db", ziggy_db_mod);
    b.installArtifact(hello_core);

    const run_hello = b.addRunArtifact(hello_core);
    if (b.args) |args| run_hello.addArgs(args);
    b.step("run-example", "Run hello_core example").dependOn(&run_hello.step);

    //
    // ────────────────────────────────────────────────
    // 3. (Optional) ZiggyDB-only example or tests later
    // ────────────────────────────────────────────────
    //
    // const ziggy_db_example = b.addExecutable(.{
    //     .name = "ziggy_db_example",
    //     .root_source_file = b.path("examples/ziggy_db_example/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // ziggy_db_example.root_module.addImport("ziggy_db", ziggy_db_mod);
    // b.installArtifact(ziggy_db_example);
}
