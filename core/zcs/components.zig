const std = @import("std");

pub const EntityId = u32;

/// Basic transform component (local space)
pub const Transform = struct {
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    rotation: [4]f32 = .{ 0.0, 0.0, 0.0, 1.0 }, // quaternion (x,y,z,w)
    scale: [3]f32 = .{ 1.0, 1.0, 1.0 },

    // cached world matrix (computed by transform system)
    world_matrix: [16]f32 = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    },
};
