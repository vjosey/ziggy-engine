const std = @import("std");
const ziggy_core = @import("ziggy_core");

const runtime_mod = ziggy_core.runtime;
const window = ziggy_core.gfx.window_glfw;
const log = ziggy_core.support.log;
const input_mod = ziggy_core.support.input;
const comps = ziggy_core.zcs.components;
const renderer2d_mod = ziggy_core.gfx.renderer2d;
const ziggy_db = @import("ziggy_db");

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
    var renderer = renderer2d_mod.Renderer2D.init(.{ 0.05, 0.05, 0.10, 1.0 });

    const e = try scene.createEntity("EditorTest");
    try scene.addTransform(e, comps.Transform{});

    // simple player entity
    const player = try scene.createEntity("Player");
    try scene.addTransform(player, comps.Transform{});
    try scene.addVelocity(player, comps.Velocity{ .value = .{ 0, 0, 0 } });
    try scene.addSprite2D(player, comps.Sprite2D{
        .size = .{ 64.0, 64.0 },
        .color = .{ 0.2, 0.7, 1.0, 1.0 },
    });

    while (!win.shouldClose()) {
        // 1. Poll events first
        win.pollEvents();

        // 2. Input
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

        if (input.isKeyDown(input_mod.Key.Up)) dir[1] += 1;
        if (input.isKeyDown(input_mod.Key.Down)) dir[1] -= 1;
        if (input.isKeyDown(input_mod.Key.Left)) dir[0] -= 1;
        if (input.isKeyDown(input_mod.Key.Right)) dir[0] += 1;

        // Normalize + apply speed so diagonal isn't faster
        const speed: f32 = 300.0; // pixels per second (tweak this to taste)
        if (dir[0] != 0 or dir[1] != 0) {
            const len = @sqrt(dir[0] * dir[0] + dir[1] * dir[1]);
            dir[0] = dir[0] / len * speed;
            dir[1] = dir[1] / len * speed;
        }

        if (scene.getVelocity(player)) |v| {
            v.value = dir;
        }

        // 3. Update ECS / systems
        rt.update();

        // 4. Begin frame on window (sets up context / maybe clears)
        win.beginFrame();

        // 5. 2D renderer work
        const fb_width: i32 = 1280;
        const fb_height: i32 = 720;

        renderer.beginFrame(fb_width, fb_height);

        // const rect_w: f32 = 100;
        // const rect_h: f32 = 80;
        // const x: f32 = (fb_width - rect_w) / 2.0;
        // const y: f32 = (fb_height - rect_h) / 2.0;

        // renderer.drawRect(x, y, rect_w, rect_h, .{ 0.2, 0.7, 1.0, 1.0 });

        // Draw all entities that have Transform + Sprite2D
        var it = scene.sprites2d.iterator();
        while (it.next()) |entry| {
            const id = entry.key_ptr.*;
            const sprite = entry.value_ptr;

            if (scene.getTransform(id)) |t| {
                const wx = t.position[0];
                const wy = t.position[1];

                const x = wx;
                const y = wy;
                const w = sprite.size[0];
                const h = sprite.size[1];

                renderer.drawRect(x, y, w, h, sprite.color);
            }
        }

        // Optional: debug log
        if (scene.getTransform(player)) |t| {
            log.info("Player pos = ({d:.2}, {d:.2}, {d:.2})", .{
                t.position[0], t.position[1], t.position[2],
            });
        }

        // 6. Present
        win.endFrame();
    }
    log.info("Hello from {s}\n", .{ziggy_db.version()});
    std.debug.print("Created entity {d} in studio runtime.\n", .{e});
    log.debug("Ziggy Studio exiting normally.\n", .{});
}
