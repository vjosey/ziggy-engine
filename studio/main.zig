const std = @import("std");
const ziggy_core = @import("ziggy_core");

const runtime_mod = ziggy_core.runtime;
const window = ziggy_core.gfx.window_glfw;
const log = ziggy_core.support.log;
const input_mod = ziggy_core.support.input;
const comps = ziggy_core.zcs.components;
const renderer2d_mod = ziggy_core.gfx.renderer2d;
const ziggy_db = @import("ziggy_db");

// New: editor layout module (from our previous step)
const studio_layout = @import("layout/studio_layout.zig");

// Simple helper to draw a panel background + header using Renderer2D
fn drawPanel(renderer: *renderer2d_mod.Renderer2D, panel: studio_layout.PanelState) void {
    const r = panel.rect;

    // Panel body (slightly transparent dark)
    renderer.drawRect(
        r.x,
        r.y,
        r.w,
        r.h,
        .{ 0.08, 0.08, 0.12, 0.9 },
    );

    // Header bar
    const header_h: f32 = 28.0;
    renderer.drawRect(
        r.x,
        r.y,
        r.w,
        header_h,
        .{ 0.14, 0.14, 0.20, 1.0 },
    );

    // (Text rendering for "Hierarchy", "Properties", etc. can be added later
    //  once we wire in a text system.)
}

pub fn main() !void {
    std.debug.print("Ziggy Studio stub running.\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Runtime setup
    var rt = try runtime_mod.ZiggyRuntime.init(allocator);
    defer rt.deinit();

    // Window setup
    const win_width: i32 = 1280;
    const win_height: i32 = 720;

    var win = try window.GlfwWindow.init(.{
        .width = win_width,
        .height = win_height,
        .title = "Ziggy Studio",
    });
    defer win.deinit();

    const scene = &rt.scene;
    var renderer = renderer2d_mod.Renderer2D.init(.{ 0.05, 0.05, 0.10, 1.0 });

    // --- ECS test entities (same as before) ---
    const e = try scene.createEntity("EditorTest");
    try scene.addTransform(e, comps.Transform{});

    const player = try scene.createEntity("Player");
    try scene.addTransform(player, comps.Transform{});
    try scene.addVelocity(player, comps.Velocity{ .value = .{ 0, 0, 0 } });
    try scene.addSprite2D(player, comps.Sprite2D{
        .size = .{ 64.0, 64.0 },
        .color = .{ 0.2, 0.7, 1.0, 1.0 },
    });

    // --- Studio layout (floating panels) ---

    // Use whole window as "viewport" for now.
    const viewport = studio_layout.Rect{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(win_width),
        .h = @floatFromInt(win_height),
    };

    var studio = try studio_layout.initStudioState(allocator, viewport);
    defer allocator.free(studio.panels);

    // Optional: ASCII debug to see layout in the console
    // studio_layout.debugPrintAsciiLayout(&studio, viewport);

    while (!win.shouldClose()) {
        // 1. Poll events
        win.pollEvents();

        // 2. Input update
        if (win.getHandle()) |handle| {
            rt.getInput().updateFromGlfw(handle);
        }

        const input = rt.getInput();

        // --- Simple movement for the test "player" sprite ---
        var dir = [3]f32{ 0, 0, 0 };
        if (input.isKeyDown(input_mod.Key.W)) dir[1] += 1;
        if (input.isKeyDown(input_mod.Key.S)) dir[1] -= 1;
        if (input.isKeyDown(input_mod.Key.A)) dir[0] -= 1;
        if (input.isKeyDown(input_mod.Key.D)) dir[0] += 1;

        if (input.isKeyDown(input_mod.Key.Up)) dir[1] += 1;
        if (input.isKeyDown(input_mod.Key.Down)) dir[1] -= 1;
        if (input.isKeyDown(input_mod.Key.Left)) dir[0] -= 1;
        if (input.isKeyDown(input_mod.Key.Right)) dir[0] += 1;

        const speed: f32 = 300.0;
        if (dir[0] != 0 or dir[1] != 0) {
            const len = @sqrt(dir[0] * dir[0] + dir[1] * dir[1]);
            dir[0] = dir[0] / len * speed;
            dir[1] = dir[1] / len * speed;
        }

        if (scene.getVelocity(player)) |v| {
            v.value = dir;
        }

        // TODO (later): hook mouse into studio_layout.handleMouseDown/Move/Up
        // using either rt.getInput() or GLFW directly.

        // 3. Update ECS / systems
        rt.update();

        // 4. Begin frame
        win.beginFrame();

        const fb_width: i32 = win_width; // later: ask window/framebuffer for real size
        const fb_height: i32 = win_height;

        renderer.beginFrame(fb_width, fb_height);

        // 4a. Editor "viewport" background (design tab)
        // For now, just a darker rectangle covering the whole area.
        renderer.drawRect(
            0,
            0,
            @floatFromInt(fb_width),
            @floatFromInt(fb_height),
            .{ 0.03, 0.03, 0.06, 1.0 },
        );

        // 4b. Draw all entities that have Transform + Sprite2D
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

        // 4c. Draw Studio panels on top of everything
        // For now we stick to the Design tab; Code tab can come later.
        studio.active_tab = studio_layout.MainTab.design;

        for (studio.panels) |panel| {
            if (!panel.visible) continue;
            if (panel.tab != studio.active_tab) continue;
            drawPanel(&renderer, panel);
        }

        // 5. Present
        win.endFrame();
    }

    log.info("Hello from {s}\n", .{ziggy_db.version()});
    std.debug.print("Created entity {d} in studio runtime.\n", .{e});
    log.debug("Ziggy Studio exiting normally.\n", .{});
}
