const std = @import("std");

// Re-export core parts in a nice namespace.
pub const runtime = @import("runtime.zig");

// ZCS sub-namespace
pub const zcs = struct {
    pub const components = @import("zcs/components.zig");
    pub const scene = @import("zcs/scene.zig");
};

pub const gfx = struct {
    pub const window_glfw = @import("gfx/window_glfw.zig");
};

pub const support = struct {
    pub const time = @import("support/time.zig");
    pub const log = @import("support/log.zig");
    pub const math = @import("support/math.zig");
    pub const input = @import("support/input_glfw.zig");
};
