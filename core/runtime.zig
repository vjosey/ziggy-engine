const std = @import("std");
const zcs_scene = @import("zcs/scene.zig");
const transform_sys = @import("zcs/systems/transforms.zig");

pub const ZiggyRuntime = struct {
    allocator: std.mem.Allocator,
    scene: zcs_scene.ZiggyScene,

    pub fn init(allocator: std.mem.Allocator) !ZiggyRuntime {
        const scene = try zcs_scene.ZiggyScene.init(allocator);
        return ZiggyRuntime{
            .allocator = allocator,
            .scene = scene,
        };
    }

    pub fn deinit(self: *ZiggyRuntime) void {
        self.scene.deinit();
    }

    pub fn update(self: *ZiggyRuntime, dt: f32) void {
        // Order of operations; later this grows:
        // 1. input
        // 2. physics
        // 3. animation
        // 4. particles
        // 5. user game logic
        // 6. transforms (world)
        // 7. render
        std.debug.print("dt: ", .{dt});

        transform_sys.updateWorldTransforms(&self.scene);
        // render2D/3D to be added here later
    }
};
