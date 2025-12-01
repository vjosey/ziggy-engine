const std = @import("std");

pub const Vec3 = [3]f32;
pub const Quat = [4]f32; // x, y, z, w
pub const Mat4 = [16]f32; // column-major 4x4 (OpenGL-style)

// Identity matrix
pub fn mat4Identity() Mat4 {
    return .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
}

// Matrix multiplication: result = a * b (column-major)
pub fn mat4Mul(a: Mat4, b: Mat4) Mat4 {
    var r: Mat4 = undefined;
    // row i, col j => i + 4*j
    var col: usize = 0;
    while (col < 4) : (col += 1) {
        var row: usize = 0;
        while (row < 4) : (row += 1) {
            var sum: f32 = 0;
            var k: usize = 0;
            while (k < 4) : (k += 1) {
                const a_idx = row + 4 * k;
                const b_idx = k + 4 * col;
                sum += a[a_idx] * b[b_idx];
            }
            r[row + 4 * col] = sum;
        }
    }
    return r;
}

// Build TRS matrix: translate * rotate * scale
pub fn mat4FromTrs(pos: Vec3, rot: Quat, scale: Vec3) Mat4 {
    // Unpack
    const x = rot[0];
    const y = rot[1];
    const z = rot[2];
    const w = rot[3];

    const sx = scale[0];
    const sy = scale[1];
    const sz = scale[2];

    const xx = x * x;
    const yy = y * y;
    const zz = z * z;
    const xy = x * y;
    const xz = x * z;
    const yz = y * z;
    const wx = w * x;
    const wy = w * y;
    const wz = w * z;

    // 3x3 rotation part
    const m00 = 1 - 2 * (yy + zz);
    const m01 = 2 * (xy - wz);
    const m02 = 2 * (xz + wy);

    const m10 = 2 * (xy + wz);
    const m11 = 1 - 2 * (xx + zz);
    const m12 = 2 * (yz - wx);

    const m20 = 2 * (xz - wy);
    const m21 = 2 * (yz + wx);
    const m22 = 1 - 2 * (xx + yy);

    // Apply scale to basis vectors
    const r00 = m00 * sx;
    const r01 = m01 * sy;
    const r02 = m02 * sz;

    const r10 = m10 * sx;
    const r11 = m11 * sy;
    const r12 = m12 * sz;

    const r20 = m20 * sx;
    const r21 = m21 * sy;
    const r22 = m22 * sz;

    // Column-major 4x4:
    // [ r00 r10 r20 0
    //   r01 r11 r21 0
    //   r02 r12 r22 0
    //   pos.x pos.y pos.z 1 ]
    return .{
        r00,    r10,    r20,    0.0,
        r01,    r11,    r21,    0.0,
        r02,    r12,    r22,    0.0,
        pos[0], pos[1], pos[2], 1.0,
    };
}

// Convenience identity quaternion (no rotation)
pub fn quatIdentity() Quat {
    return .{ 0.0, 0.0, 0.0, 1.0 };
}
