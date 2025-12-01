const std = @import("std");
const math = @import("../support/math.zig");

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

pub const Velocity = struct {
    value: [3]f32,
};

pub const Camera = struct {
    // vertical FOV (radians)
    fov_y: f32 = std.math.degreesToRadians(60.0),
    near: f32 = 0.1,
    far: f32 = 100.0,
    aspect: f32 = 16.0 / 9.0,

    // where the camera is looking (world-space)
    target: [3]f32 = .{ 0.0, 0.0, 0.0 },
    up: [3]f32 = .{ 0.0, 1.0, 0.0 },

    view: math.Mat4 = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    },
    proj: math.Mat4 = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    },
    view_proj: math.Mat4 = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    },
};
