const std = @import("std");

pub const Time = struct {
    /// Target fixed-step size in seconds (e.g. 1.0 / 60.0).
    fixed_step: f64,

    /// Accumulator for fixed-step logic.
    accumulator: f64,

    /// Delta time (seconds) between the last two `update` calls.
    delta: f32,

    /// Total elapsed time in seconds since initialization.
    elapsed: f64,

    /// Timestamp of the previous update in nanoseconds.
    /// Use same type as std.time.nanoTimestamp() (i128 in your Zig).
    last_ns: i128,

    pub fn init(fixed_step: f64) Time {
        return .{
            .fixed_step = fixed_step,
            .accumulator = 0,
            .delta = 0,
            .elapsed = 0,
            .last_ns = std.time.nanoTimestamp(),
        };
    }

    pub fn reset(self: *Time) void {
        self.accumulator = 0;
        self.delta = 0;
        self.elapsed = 0;
        self.last_ns = std.time.nanoTimestamp();
    }

    /// Update internal timing based on the current timestamp.
    /// - Updates `delta` (frame dt)
    /// - Updates `elapsed`
    /// - Accumulates time into `accumulator` for fixed-step logic
    pub fn update(self: *Time) void {
        const now_ns: i128 = std.time.nanoTimestamp();
        const dt_ns: i128 = now_ns - self.last_ns;
        self.last_ns = now_ns;

        const dt_sec: f64 = @as(f64, @floatFromInt(dt_ns)) / 1_000_000_000.0;

        self.delta = @as(f32, @floatCast(dt_sec));
        self.elapsed += dt_sec;
        self.accumulator += dt_sec;
    }

    /// Whether we have enough accumulated time for at least one fixed update.
    pub fn stepAvailable(self: *Time) bool {
        return self.accumulator >= self.fixed_step;
    }

    /// Consume one fixed step and return its duration in seconds (as f32).
    pub fn consumeFixedStep(self: *Time) f32 {
        self.accumulator -= self.fixed_step;
        return @as(f32, @floatCast(self.fixed_step));
    }
};
