const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    // ==================== Constructors ====================

    /// Create rectangle from top-left position and size
    pub fn init(x: f32, y: f32, width: f32, height: f32) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    /// Create rectangle from center point and half-extents
    pub fn fromCenter(center_point: Vec2, half_size: Vec2) Rect {
        return .{
            .x = center_point.x - half_size.x,
            .y = center_point.y - half_size.y,
            .width = half_size.x * 2,
            .height = half_size.y * 2,
        };
    }

    /// Create rectangle from two corner points
    pub fn fromCorners(min: Vec2, max: Vec2) Rect {
        return .{
            .x = min.x,
            .y = min.y,
            .width = max.x - min.x,
            .height = max.y - min.y,
        };
    }

    // ==================== Queries ====================

    pub fn contains(self: Rect, point: Vec2) bool {
        return point.x >= self.x and
            point.x <= self.x + self.width and
            point.y >= self.y and
            point.y <= self.y + self.height;
    }

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }

    pub fn intersection(self: Rect, other: Rect) ?Rect {
        if (!self.intersects(other)) return null;

        const left = @max(self.x, other.x);
        const top = @max(self.y, other.y);
        const right = @min(self.x + self.width, other.x + other.width);
        const bottom = @min(self.y + self.height, other.y + other.height);

        return Rect{
            .x = left,
            .y = top,
            .width = right - left,
            .height = bottom - top,
        };
    }

    // ==================== Properties ====================

    pub fn center(self: Rect) Vec2 {
        return .{
            .x = self.x + self.width * 0.5,
            .y = self.y + self.height * 0.5,
        };
    }

    pub fn size(self: Rect) Vec2 {
        return .{ .x = self.width, .y = self.height };
    }

    pub fn halfSize(self: Rect) Vec2 {
        return .{ .x = self.width * 0.5, .y = self.height * 0.5 };
    }

    /// Get corner positions
    pub fn topLeft(self: Rect) Vec2 {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn topRight(self: Rect) Vec2 {
        return .{ .x = self.x + self.width, .y = self.y };
    }

    pub fn bottomLeft(self: Rect) Vec2 {
        return .{ .x = self.x, .y = self.y + self.height };
    }

    pub fn bottomRight(self: Rect) Vec2 {
        return .{ .x = self.x + self.width, .y = self.y + self.height };
    }

    /// Get edge midpoints
    pub fn topCenter(self: Rect) Vec2 {
        return .{ .x = self.x + self.width * 0.5, .y = self.y };
    }

    pub fn bottomCenter(self: Rect) Vec2 {
        return .{ .x = self.x + self.width * 0.5, .y = self.y + self.height };
    }

    pub fn leftCenter(self: Rect) Vec2 {
        return .{ .x = self.x, .y = self.y + self.height * 0.5 };
    }

    pub fn rightCenter(self: Rect) Vec2 {
        return .{ .x = self.x + self.width, .y = self.y + self.height * 0.5 };
    }

    // ==================== Transformations ====================

    /// Expand rectangle by amount on all sides
    pub fn expand(self: Rect, amount: f32) Rect {
        return .{
            .x = self.x - amount,
            .y = self.y - amount,
            .width = self.width + amount * 2,
            .height = self.height + amount * 2,
        };
    }

    /// Shrink rectangle by amount on all sides
    pub fn shrink(self: Rect, amount: f32) Rect {
        return self.expand(-amount);
    }

    /// Translate rectangle by offset
    pub fn translate(self: Rect, offset: Vec2) Rect {
        return .{
            .x = self.x + offset.x,
            .y = self.y + offset.y,
            .width = self.width,
            .height = self.height,
        };
    }

    /// Scale rectangle around its center
    pub fn scale(self: Rect, factor: f32) Rect {
        const c = self.center();
        const new_half_size = self.halfSize().scale(factor);
        return fromCenter(c, new_half_size);
    }

    // ==================== Advanced Queries ====================

    pub fn closestPoint(self: Rect, point: Vec2) Vec2 {
        return .{
            .x = std.math.clamp(point.x, self.x, self.x + self.width),
            .y = std.math.clamp(point.y, self.y, self.y + self.height),
        };
    }

    pub fn distanceToPoint(self: Rect, point: Vec2) f32 {
        const closest = self.closestPoint(point);
        return point.distance(closest);
    }

    pub fn area(self: Rect) f32 {
        return self.width * self.height;
    }

    pub fn perimeter(self: Rect) f32 {
        return 2 * (self.width + self.height);
    }

    // ==================== Utilities ====================

    pub fn equals(self: Rect, other: Rect) bool {
        return self.x == other.x and
            self.y == other.y and
            self.width == other.width and
            self.height == other.height;
    }

    pub fn format(
        self: Rect,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Rect({d:.1}, {d:.1}, {d:.1}x{d:.1})", .{ self.x, self.y, self.width, self.height });
    }
};
