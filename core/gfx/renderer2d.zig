// core/gfx/renderer2d.zig
const std = @import("std");

// Use explicit extern declarations instead of @cImport(GL/gl.h)
// so we don't depend on libc headers.

const CInt = c_int;
const CUInt = c_uint;

// Minimal set of OpenGL functions we need
extern fn glViewport(x: CInt, y: CInt, width: CInt, height: CInt) void;
extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
extern fn glClear(mask: CUInt) void;
extern fn glMatrixMode(mode: CUInt) void;
extern fn glLoadIdentity() void;
extern fn glOrtho(left: f64, right: f64, bottom: f64, top: f64, near: f64, far: f64) void;
extern fn glColor4f(r: f32, g: f32, b: f32, a: f32) void;
extern fn glBegin(mode: CUInt) void;
extern fn glVertex2f(x: f32, y: f32) void;
extern fn glEnd() void;

// Minimal constants (same values as in GL headers)
const GL_COLOR_BUFFER_BIT: CUInt = 0x0000_4000;
const GL_PROJECTION: CUInt = 0x1701;
const GL_MODELVIEW: CUInt = 0x1700;
const GL_QUADS: CUInt = 0x0007;

pub const Renderer2D = struct {
    clear_color: [4]f32,

    pub fn init(clear_color: [4]f32) Renderer2D {
        return .{
            .clear_color = clear_color,
        };
    }

    /// Call at the start of each frame.
    /// `width` and `height` are the framebuffer size in pixels.
    pub fn beginFrame(self: *const Renderer2D, width: i32, height: i32) void {
        glViewport(@as(CInt, @intCast(0)), @as(CInt, @intCast(0)), @as(CInt, @intCast(width)), @as(CInt, @intCast(height)));

        glClearColor(self.clear_color[0], self.clear_color[1], self.clear_color[2], self.clear_color[3]);
        glClear(GL_COLOR_BUFFER_BIT);

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        // glOrtho(left, right, bottom, top, near, far)
        glOrtho(
            0.0,
            @as(f64, @floatFromInt(width)),
            0.0,
            @as(f64, @floatFromInt(height)),
            -1.0,
            1.0,
        );

        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
    }

    /// Draw a solid colored rectangle in screen space.
    /// (x, y) is bottom-left, width/height in pixels.
    pub fn drawRect(self: *const Renderer2D, x: f32, y: f32, w: f32, h: f32, color: [4]f32) void {
        _ = self;

        glColor4f(color[0], color[1], color[2], color[3]);

        glBegin(GL_QUADS);
        glVertex2f(x, y); // bottom-left
        glVertex2f(x + w, y); // bottom-right
        glVertex2f(x + w, y + h); // top-right
        glVertex2f(x, y + h); // top-left
        glEnd();
    }
};
