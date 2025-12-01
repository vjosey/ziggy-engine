const std = @import("std");
const zcs_scene = @import("zcs/scene.zig");
const time_mod = @import("support/time.zig");
const log = @import("support/log.zig");
const movement_system = @import("zcs/systems/movement.zig");
const transform_system = @import("zcs/systems/transforms.zig");
const camera_system = @import("zcs/systems/camera.zig");
const input_mod = @import("support/input_glfw.zig");

pub const SystemFn = *const fn (*zcs_scene.ZiggyScene, f32) void;

pub const ZiggyRuntime = struct {
    allocator: std.mem.Allocator,
    scene: zcs_scene.ZiggyScene,
    time: time_mod.Time,
    /// Systems that run once per frame (variable dt)
    frame_systems: std.ArrayList(SystemFn),
    /// Systems that run at a fixed timestep (fixed dt)
    fixed_systems: std.ArrayList(SystemFn),
    input: input_mod.Input,

    pub fn init(allocator: std.mem.Allocator) !ZiggyRuntime {
        const scene = try zcs_scene.ZiggyScene.init(allocator);
        var rt = ZiggyRuntime{
            .allocator = allocator,
            .scene = scene,
            .time = time_mod.Time.init(1.0 / 60.0),
            .frame_systems = std.ArrayList(SystemFn).init(allocator),
            .fixed_systems = std.ArrayList(SystemFn).init(allocator),
            .input = input_mod.Input.init(),
        };

        // register systems
        try rt.addFrameSystem(movement_system.update);
        try rt.addFrameSystem(transform_system.update);
        try rt.addFrameSystem(camera_system.update);

        // later: try rt.addFixedSystem(physics_system.update);

        return rt;
    }

    pub fn deinit(self: *ZiggyRuntime) void {
        self.scene.deinit();
        self.frame_systems.deinit();
        self.fixed_systems.deinit();
    }

    /// Access the input system
    pub fn getInput(self: *ZiggyRuntime) *input_mod.Input {
        return &self.input;
    }

    /// Register a system to run every frame at variable dt
    pub fn addFrameSystem(self: *ZiggyRuntime, sys: SystemFn) !void {
        try self.frame_systems.append(sys);
    }

    /// Register a system to run at fixed dt
    pub fn addFixedSystem(self: *ZiggyRuntime, sys: SystemFn) !void {
        try self.fixed_systems.append(sys);
    }

    pub fn update(self: *ZiggyRuntime) void {
        // Order of operations; later this grows:
        // 1. input
        // 2. physics
        // 3. animation
        // 4. particles
        // 5. user game logic
        // 6. transforms (world)
        // 7. render
        self.time.update();

        const dt_frame: f32 = self.time.delta;

        // ───────────────────────────────
        // 1. RUN FRAME-BASED SYSTEMS
        //    (input, UI, animation, movement)
        // ───────────────────────────────
        for (self.frame_systems.items) |sys| {
            sys(&self.scene, dt_frame);
        }

        // ───────────────────────────────
        // 2. RUN FIXED-STEP SYSTEMS
        //    (physics, deterministic logic)
        // ───────────────────────────────
        while (self.time.stepAvailable()) {
            const dt_fixed: f32 = self.time.consumeFixedStep();

            for (self.fixed_systems.items) |sys| {
                sys(&self.scene, dt_fixed);
            }
        }

        // render2D/3D to be added here later
    }

    pub fn getTime(self: *ZiggyRuntime) *time_mod.Time {
        return &self.time;
    }
};
