const std = @import("std");
const ziggy_core = @import("ziggy_core");

const runtime_mod = ziggy_core.runtime;
const window = ziggy_core.gfx.window_glfw;
const log = ziggy_core.support.log;
const input_mod = ziggy_core.support.input;
const comps = ziggy_core.zcs.components;

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

    const e = try scene.createEntity("EditorTest");
    try scene.addTransform(e, comps.Transform{});

    // simple player entity
    const player = try scene.createEntity("Player");
    try scene.addTransform(player, comps.Transform{});
    try scene.addVelocity(player, comps.Velocity{ .value = .{ 0, 0, 0 } });

    while (!win.shouldClose()) {
        if (win.getHandle()) |handle| {
            rt.getInput().updateFromGlfw(handle);
        }

        // Map input → velocity
        const input = rt.getInput();
        var dir = [3]f32{ 0, 0, 0 };
        if (input.isKeyDown(input_mod.Key.W)) dir[1] += 1;
        if (input.isKeyDown(input_mod.Key.S)) dir[1] -= 1;
        if (input.isKeyDown(input_mod.Key.A)) dir[0] -= 1;
        if (input.isKeyDown(input_mod.Key.D)) dir[0] += 1;

        if (scene.getVelocity(player)) |v| {
            v.value = dir;
        }

        // Update core runtime (your ECS, systems, etc.)
        rt.update();

        // log the position to prove it’s working
        if (scene.getTransform(player)) |t| {
            log.info("Player pos = ({d:.2}, {d:.2}, {d:.2})", .{
                t.position[0], t.position[1], t.position[2],
            });
        }

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
