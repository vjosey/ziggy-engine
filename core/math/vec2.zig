const std = @import("std");

pub const Vec2 = struct {
    x: f32,
    y: f32,

    // ==================== Constants ====================
    pub const zero = Vec2{ .x = 0, .y = 0 };
    pub const one = Vec2{ .x = 1, .y = 1 };
    pub const up = Vec2{ .x = 0, .y = -1 }; // Screen coords: -Y is up
    pub const down = Vec2{ .x = 0, .y = 1 };
    pub const left = Vec2{ .x = -1, .y = 0 };
    pub const right = Vec2{ .x = 1, .y = 0 };

    // ==================== Basic Operations ====================

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn mul(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x * other.x, .y = self.y * other.y };
    }

    pub fn div(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x / other.x, .y = self.y / other.y };
    }

    // ==================== Scalar Operations ====================

    pub fn scale(self: Vec2, scalar: f32) Vec2 {
        return .{ .x = self.x * scalar, .y = self.y * scalar };
    }

    pub fn divScalar(self: Vec2, scalar: f32) Vec2 {
        return .{ .x = self.x / scalar, .y = self.y / scalar };
    }

    // ==================== Vector Math ====================

    pub fn dot(self: Vec2, other: Vec2) f32 {
        return self.x * other.x + self.y * other.y;
    }

    /// Cross product in 2D returns a scalar (Z component of 3D cross product)
    /// Useful for determining rotation direction
    pub fn cross(self: Vec2, other: Vec2) f32 {
        return self.x * other.y - self.y * other.x;
    }

    pub fn magnitude(self: Vec2) f32 {
        return std.math.sqrt(self.x * self.x + self.y * self.y);
    }

    /// Faster than magnitude() - avoids sqrt
    /// Use for distance comparisons: if (a.magnitudeSq() < b.magnitudeSq())
    pub fn magnitudeSq(self: Vec2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    /// Returns normalized vector (length = 1)
    /// Returns zero vector if magnitude is zero
    pub fn normalize(self: Vec2) Vec2 {
        const mag = self.magnitude();
        if (mag == 0) return Vec2.zero;
        return self.divScalar(mag);
    }

    pub fn normalizeWithMagnitude(self: Vec2, mag: f32) Vec2 {
        if (mag == 0) return Vec2.zero;
        return self.divScalar(mag);
    }

    // ==================== Distance & Geometric ====================

    pub fn distance(self: Vec2, other: Vec2) f32 {
        return self.sub(other).magnitude();
    }

    pub fn distanceSq(self: Vec2, other: Vec2) f32 {
        return self.sub(other).magnitudeSq();
    }

    /// Linear interpolation: lerp(a, b, 0.5) = midpoint
    pub fn lerp(self: Vec2, other: Vec2, t: f32) Vec2 {
        return .{
            .x = self.x + (other.x - self.x) * t,
            .y = self.y + (other.y - self.y) * t,
        };
    }

    /// Returns angle in radians between two vectors
    pub fn angle(self: Vec2, other: Vec2) f32 {
        const d = self.dot(other);
        const mag_product = self.magnitude() * other.magnitude();
        if (mag_product == 0) return 0;
        return std.math.acos(std.math.clamp(d / mag_product, -1.0, 1.0));
    }

    /// Rotate vector by angle (radians)
    pub fn rotate(self: Vec2, radians: f32) Vec2 {
        const cos = std.math.cos(radians);
        const sin = std.math.sin(radians);
        return .{
            .x = self.x * cos - self.y * sin,
            .y = self.x * sin + self.y * cos,
        };
    }

    /// Returns perpendicular vector (rotated 90° counter-clockwise)
    pub fn perpendicular(self: Vec2) Vec2 {
        return .{ .x = -self.y, .y = self.x };
    }

    // ==================== Reflection & Projection ====================

    /// Reflect vector across normal
    pub fn reflect(self: Vec2, normal: Vec2) Vec2 {
        const d = self.dot(normal);
        return self.sub(normal.scale(2 * d));
    }

    /// Project this vector onto another
    pub fn project(self: Vec2, onto: Vec2) Vec2 {
        const mag_sq = onto.magnitudeSq();
        if (mag_sq == 0) return Vec2.zero;
        const scalar = self.dot(onto) / mag_sq;
        return onto.scale(scalar);
    }

    // ==================== Utility ====================

    pub fn negate(self: Vec2) Vec2 {
        return .{ .x = -self.x, .y = -self.y };
    }

    pub fn abs(self: Vec2) Vec2 {
        return .{ .x = @abs(self.x), .y = @abs(self.y) };
    }

    pub fn equals(self: Vec2, other: Vec2) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn approxEquals(self: Vec2, other: Vec2, epsilon: f32) bool {
        return @abs(self.x - other.x) <= epsilon and
            @abs(self.y - other.y) <= epsilon;
    }

    pub fn min(self: Vec2, other: Vec2) Vec2 {
        return .{
            .x = @min(self.x, other.x),
            .y = @min(self.y, other.y),
        };
    }

    pub fn max(self: Vec2, other: Vec2) Vec2 {
        return .{
            .x = @max(self.x, other.x),
            .y = @max(self.y, other.y),
        };
    }

    pub fn clamp(self: Vec2, min_vec: Vec2, max_vec: Vec2) Vec2 {
        return .{
            .x = std.math.clamp(self.x, min_vec.x, max_vec.x),
            .y = std.math.clamp(self.y, min_vec.y, max_vec.y),
        };
    }

    // ==================== Debug ====================

    pub fn print(self: Vec2) void {
        std.debug.print("Vec2({d:.2}, {d:.2})\n", .{ self.x, self.y });
    }

    pub fn format(
        self: Vec2,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("({d:.2}, {d:.2})", .{ self.x, self.y });
    }
};
