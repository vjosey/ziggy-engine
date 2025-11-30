const std = @import("std");
const ziggy_core = @import("ziggy_core");

const runtime_mod = ziggy_core.runtime;
const window = ziggy_core.gfx.window_glfw;
const log = ziggy_core.support.log;

pub fn main() !void {
    std.debug.print("Ziggy Studio stub running.\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //runtime setup
    var rt = try runtime_mod.ZiggyRuntime.init(allocator);
    defer rt.deinit();

    // Window setup
    var win = try window.GlfwWindow.init(.{
        .width = 1280,
        .height = 720,
        .title = "Ziggy Studio",
    });
    defer win.deinit();

    const scene = &rt.scene;
    const comps = ziggy_core.zcs.components;

    const e = try scene.createEntity("EditorTest");
    try scene.addTransform(e, comps.Transform{});

    while (!win.shouldClose()) {
        // Update core runtime (your ECS, systems, etc.)
        rt.update();

        // Render (for now, just clear)
        win.beginFrame();
        // TODO: draw runtime/scene here later
        win.endFrame();

        // Poll events
        win.pollEvents();
    }

    std.debug.print("Created entity {d} in studio runtime.\n", .{e});
    log.debug("Ziggy Studio exiting normally.\n", .{});
}
