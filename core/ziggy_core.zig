const std = @import("std");

// Re-export core parts in a nice namespace.
pub const runtime = @import("runtime.zig");

// ZCS sub-namespace
pub const zcs = struct {
    pub const components = @import("zcs/components.zig");
    pub const scene = @import("zcs/scene.zig");
};
