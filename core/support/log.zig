const std = @import("std");

fn logPrint(comptime prefix: []const u8, comptime fmt: []const u8, args: anytype) void {
    // Central place to customize formatting behavior
    // NOTE: callers must still pass args matching `fmt`.
    std.debug.print(prefix ++ fmt ++ "\n", args);
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    logPrint("[INFO]  ", fmt, args);
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    logPrint("[WARN]  ", fmt, args);
}

pub fn errorf(comptime fmt: []const u8, args: anytype) void {
    logPrint("[ERROR] ", fmt, args);
}

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    logPrint("[DEBUG] ", fmt, args);
}
