const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("ziggy_core", .{
        .root_source_file = b.path("ziggy_core.zig"),
    });
}
