const std = @import("std");

/// Quaternion stored as: x, y, z, w
pub const Quat = [4]f32;

/// Convenience identity quaternion (no rotation)
pub inline fn identity() Quat {
    return .{ 0.0, 0.0, 0.0, 1.0 };
}

/// Normalize quaternion to unit length (important for rotations)
pub inline fn normalize(q: Quat) Quat {
    const len_sq = q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3];
    if (len_sq == 0) return identity();
    const inv_len = 1.0 / @sqrt(len_sq);
    return .{ q[0] * inv_len, q[1] * inv_len, q[2] * inv_len, q[3] * inv_len };
}
