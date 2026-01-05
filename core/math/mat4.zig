const std = @import("std");

const vec3 = @import("vec3.zig");
const quat = @import("quat.zig");

pub const Vec3 = vec3.Vec3;
pub const Quat = quat.Quat;

/// Column-major 4x4 (OpenGL-style)
pub const Mat4 = [16]f32;

/// Identity matrix
pub inline fn identity() Mat4 {
    return .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
}

/// Matrix multiplication: result = a * b (column-major)
pub fn mul(a: Mat4, b: Mat4) Mat4 {
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

/// Build TRS matrix: translate * rotate * scale
pub fn fromTrs(pos: Vec3, rot: Quat, scale: Vec3) Mat4 {
    // Unpack quat
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

    // 3x3 rotation
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

    // Column-major 4x4
    return .{
        r00,    r10,    r20,    0.0,
        r01,    r11,    r21,    0.0,
        r02,    r12,    r22,    0.0,
        pos[0], pos[1], pos[2], 1.0,
    };
}

/// Standard right-handed lookAt (eye → target, with up)
pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
    const f = vec3.normalize(vec3.sub(target, eye)); // forward
    const s = vec3.normalize(vec3.cross(f, up)); // right
    const u = vec3.cross(s, f); // recomputed up

    const sx = s[0];
    const sy = s[1];
    const sz = s[2];

    const ux = u[0];
    const uy = u[1];
    const uz = u[2];

    const fx = f[0];
    const fy = f[1];
    const fz = f[2];

    return .{
        sx,                ux,                -fx,              0.0,
        sy,                uy,                -fy,              0.0,
        sz,                uz,                -fz,              0.0,
        -vec3.dot(s, eye), -vec3.dot(u, eye), vec3.dot(f, eye), 1.0,
    };
}

/// Perspective projection (OpenGL-style, right-handed, column-major)
pub fn perspective(fov_y_radians: f32, aspect: f32, z_near: f32, z_far: f32) Mat4 {
    const f = 1.0 / @tan(fov_y_radians / 2.0);
    const nf = 1.0 / (z_near - z_far);

    return .{
        f / aspect, 0, 0,                       0,
        0,          f, 0,                       0,
        0,          0, (z_far + z_near) * nf,   -1,
        0,          0, 2 * z_far * z_near * nf, 0,
    };
}
