const std = @import("std");

// Opaque GLFW types
const GLFWwindow = opaque {};
const GLFWmonitor = opaque {};

// ---- GLFW externs ----
extern fn glfwInit() c_int;
extern fn glfwTerminate() void;

extern fn glfwCreateWindow(
    width: c_int,
    height: c_int,
    title: [*c]const u8,
    monitor: ?*GLFWmonitor,
    share: ?*GLFWwindow,
) ?*GLFWwindow;

extern fn glfwDestroyWindow(window: *GLFWwindow) void;
extern fn glfwMakeContextCurrent(window: ?*GLFWwindow) void;
extern fn glfwSwapInterval(interval: c_int) void;
extern fn glfwWindowShouldClose(window: *GLFWwindow) c_int;
extern fn glfwPollEvents() void;
extern fn glfwSwapBuffers(window: *GLFWwindow) void;

// ---- OpenGL externs ----
extern fn glViewport(x: c_int, y: c_int, width: c_int, height: c_int) void;
extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
extern fn glClear(mask: u32) void;

const GL_COLOR_BUFFER_BIT: u32 = 0x0000_4000;

// ---- Public API ----

pub const WindowError = error{
    GlfwInitFailed,
    WindowCreationFailed,
};

pub const WindowConfig = struct {
    width: u32 = 1280,
    height: u32 = 720,
    title: []const u8 = "Ziggy Studio",
};

pub const GlfwWindow = struct {
    config: WindowConfig,
    handle: ?*GLFWwindow,

    pub fn init(config: WindowConfig) !GlfwWindow {
        if (glfwInit() == 0) {
            return WindowError.GlfwInitFailed;
        }

        const w = glfwCreateWindow(
            @intCast(config.width),
            @intCast(config.height),
            config.title.ptr,
            null,
            null,
        );
        if (w == null) {
            glfwTerminate();
            return WindowError.WindowCreationFailed;
        }

        glfwMakeContextCurrent(w);
        glfwSwapInterval(1);

        return GlfwWindow{
            .config = config,
            .handle = w,
        };
    }

    pub fn deinit(self: *GlfwWindow) void {
        if (self.handle) |w| {
            glfwDestroyWindow(w);
            self.handle = null;
        }
        glfwTerminate();
    }

    pub fn shouldClose(self: *GlfwWindow) bool {
        if (self.handle) |w| {
            return glfwWindowShouldClose(w) != 0;
        }
        return true;
    }

    pub fn pollEvents(_: *GlfwWindow) void {
        glfwPollEvents();
    }

    pub fn beginFrame(self: *GlfwWindow) void {
        if (self.handle == null) return;

        glViewport(
            0,
            0,
            @intCast(self.config.width),
            @intCast(self.config.height),
        );
        glClearColor(0.1, 0.1, 0.15, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
    }

    pub fn endFrame(self: *GlfwWindow) void {
        if (self.handle) |w| {
            glfwSwapBuffers(w);
        }
    }
};
