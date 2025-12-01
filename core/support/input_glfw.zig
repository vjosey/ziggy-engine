const std = @import("std");
const window_gfx = @import("../gfx/window_glfw.zig");

pub const GLFWwindow = window_gfx.GLFWwindow;

extern fn glfwGetKey(window: *GLFWwindow, key: c_int) c_int;

const GLFW_PRESS: c_int = 1;
const GLFW_REPEAT: c_int = 2;

/// Limited set of keys we care about for now.
/// Values match GLFW key codes.
pub const Key = enum(u16) {
    W = 87, // GLFW_KEY_W
    A = 65, // GLFW_KEY_A
    S = 83, // GLFW_KEY_S
    D = 68, // GLFW_KEY_D
    Space = 32, // GLFW_KEY_SPACE
    Escape = 256, // GLFW_KEY_ESCAPE
    Up = 265, // GLFW_KEY_UP
    Down = 264, // GLFW_KEY_DOWN
    Left = 263, // GLFW_KEY_LEFT
    Right = 262, // GLFW_KEY_RIGHT,
};

const max_keys = 512;

pub const Input = struct {
    keys_current: [max_keys]u8,
    keys_previous: [max_keys]u8,

    pub fn init() Input {
        return .{
            .keys_current = [_]u8{0} ** max_keys,
            .keys_previous = [_]u8{0} ** max_keys,
        };
    }

    fn keyIndex(key: Key) usize {
        return @intFromEnum(key);
    }

    /// Copy current state to previous at the start of a frame
    pub fn beginFrame(self: *Input) void {
        self.keys_previous = self.keys_current;
    }

    /// Poll GLFW for the keys we track and update current state.
    /// Call this once per frame after glfwPollEvents().
    pub fn updateFromGlfw(self: *Input, window: *GLFWwindow) void {
        self.beginFrame();

        const tracked_keys = [_]Key{
            .W,     .A,      .S,  .D,
            .Space, .Escape, .Up, .Down,
            .Left,  .Right,
        };

        for (tracked_keys) |key| {
            const idx = keyIndex(key);
            const state = glfwGetKey(window, @as(c_int, @intCast(idx)));
            self.keys_current[idx] =
                if (state == GLFW_PRESS or state == GLFW_REPEAT) 1 else 0;
        }
    }

    pub fn isKeyDown(self: *Input, key: Key) bool {
        return self.keys_current[keyIndex(key)] != 0;
    }

    pub fn wasKeyPressed(self: *Input, key: Key) bool {
        const idx = keyIndex(key);
        return self.keys_current[idx] != 0 and self.keys_previous[idx] == 0;
    }

    pub fn wasKeyReleased(self: *Input, key: Key) bool {
        const idx = keyIndex(key);
        return self.keys_current[idx] == 0 and self.keys_previous[idx] != 0;
    }
};
