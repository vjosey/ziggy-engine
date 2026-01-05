const std = @import("std");

pub const Color = struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 1.0,

    pub inline fn init(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub inline fn rgb(r: f32, g: f32, b: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1.0 };
    }

    pub inline fn rgba8(r8: u8, g8: u8, b8: u8, a8: u8) Color {
        return .{
            .r = @as(f32, @floatFromInt(r8)) / 255.0,
            .g = @as(f32, @floatFromInt(g8)) / 255.0,
            .b = @as(f32, @floatFromInt(b8)) / 255.0,
            .a = @as(f32, @floatFromInt(a8)) / 255.0,
        };
    }

    pub inline fn identityBlack() Color {
        return .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    }

    // ─────────────────────────────────────────────
    // Basic ops
    // ─────────────────────────────────────────────

    pub inline fn add(a: Color, b: Color) Color {
        return .{ .r = a.r + b.r, .g = a.g + b.g, .b = a.b + b.b, .a = a.a + b.a };
    }

    pub inline fn sub(a: Color, b: Color) Color {
        return .{ .r = a.r - b.r, .g = a.g - b.g, .b = a.b - b.b, .a = a.a - b.a };
    }

    pub inline fn mul(a: Color, b: Color) Color {
        return .{ .r = a.r * b.r, .g = a.g * b.g, .b = a.b * b.b, .a = a.a * b.a };
    }

    pub inline fn mulScalar(c: Color, s: f32) Color {
        return .{ .r = c.r * s, .g = c.g * s, .b = c.b * s, .a = c.a * s };
    }

    pub inline fn divScalar(c: Color, s: f32) Color {
        return .{ .r = c.r / s, .g = c.g / s, .b = c.b / s, .a = c.a / s };
    }

    pub inline fn inverted(c: Color) Color {
        return .{ .r = 1.0 - c.r, .g = 1.0 - c.g, .b = 1.0 - c.b, .a = c.a };
    }

    pub inline fn clamp(c: Color, min: Color, max: Color) Color {
        return .{
            .r = std.math.clamp(c.r, min.r, max.r),
            .g = std.math.clamp(c.g, min.g, max.g),
            .b = std.math.clamp(c.b, min.b, max.b),
            .a = std.math.clamp(c.a, min.a, max.a),
        };
    }

    pub inline fn lerp(from: Color, to: Color, t: f32) Color {
        return .{
            .r = from.r + (to.r - from.r) * t,
            .g = from.g + (to.g - from.g) * t,
            .b = from.b + (to.b - from.b) * t,
            .a = from.a + (to.a - from.a) * t,
        };
    }

    pub inline fn darkened(c: Color, amount: f32) Color {
        // amount in [0..1] typical; >1 allowed if you want.
        const k = 1.0 - amount;
        return .{ .r = c.r * k, .g = c.g * k, .b = c.b * k, .a = c.a };
    }

    pub inline fn lightened(c: Color, amount: f32) Color {
        // Move towards white
        return lerp(c, .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = c.a }, amount);
    }

    /// Standard alpha compositing: "this over under".
    /// Equivalent to Godot's blend(over) style compositing. :contentReference[oaicite:1]{index=1}
    pub inline fn blend(under: Color, over: Color) Color {
        const oa = std.math.clamp(over.a, 0.0, 1.0);
        const ua = std.math.clamp(under.a, 0.0, 1.0);

        const out_a = oa + ua * (1.0 - oa);
        if (out_a <= 0.0) return .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 };

        const r = (over.r * oa + under.r * ua * (1.0 - oa)) / out_a;
        const g = (over.g * oa + under.g * ua * (1.0 - oa)) / out_a;
        const b = (over.b * oa + under.b * ua * (1.0 - oa)) / out_a;

        return .{ .r = r, .g = g, .b = b, .a = out_a };
    }

    /// Relative luminance (Rec.709 / sRGB primaries).
    pub inline fn luminance(c: Color) f32 {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    pub inline fn isEqualApprox(a: Color, b: Color, eps: f32) bool {
        return (@abs(a.r - b.r) <= eps) and
            (@abs(a.g - b.g) <= eps) and
            (@abs(a.b - b.b) <= eps) and
            (@abs(a.a - b.a) <= eps);
    }

    // ─────────────────────────────────────────────
    // HSV
    // ─────────────────────────────────────────────

    /// Create from HSV where h,s,v are typically [0..1], alpha default 1.0. :contentReference[oaicite:3]{index=3}
    pub fn fromHsv(h: f32, s: f32, v: f32, a: f32) Color {
        const hh = h - @floor(h); // wrap to [0,1)
        const ss = std.math.clamp(s, 0.0, 1.0);
        const vv = v;

        if (ss == 0.0) {
            return .{ .r = vv, .g = vv, .b = vv, .a = a };
        }

        const hf = hh * 6.0;
        const i: i32 = @intFromFloat(@floor(hf));
        const f = hf - @as(f32, @floatFromInt(i));

        const p = vv * (1.0 - ss);
        const q = vv * (1.0 - ss * f);
        const t = vv * (1.0 - ss * (1.0 - f));

        return switch (@mod(i, 6)) {
            0 => .{ .r = vv, .g = t, .b = p, .a = a },
            1 => .{ .r = q, .g = vv, .b = p, .a = a },
            2 => .{ .r = p, .g = vv, .b = t, .a = a },
            3 => .{ .r = p, .g = q, .b = vv, .a = a },
            4 => .{ .r = t, .g = p, .b = vv, .a = a },
            else => .{ .r = vv, .g = p, .b = q, .a = a },
        };
    }

    /// Convert to HSV (h,s,v in [0..1] typical). Returns (h,s,v,a) packed in a Color-like struct.
    pub fn toHsv(c: Color) struct { h: f32, s: f32, v: f32, a: f32 } {
        const r = c.r;
        const g = c.g;
        const b = c.b;

        const maxv = @max(r, @max(g, b));
        const minv = @min(r, @min(g, b));
        const d = maxv - minv;

        var h: f32 = 0.0;
        const s: f32 = if (maxv == 0.0) 0.0 else d / maxv;
        const v: f32 = maxv;

        if (d != 0.0) {
            if (maxv == r) {
                h = (g - b) / d + (if (g < b) 6.0 else 0.0);
            } else if (maxv == g) {
                h = (b - r) / d + 2.0;
            } else {
                h = (r - g) / d + 4.0;
            }
            h /= 6.0;
        }

        return .{ .h = h, .s = s, .v = v, .a = c.a };
    }

    // ─────────────────────────────────────────────
    // sRGB ↔ Linear
    // ─────────────────────────────────────────────

    /// Convert an sRGB channel to linear (approx exact sRGB transfer function).
    fn srgbChannelToLinear(x: f32) f32 {
        if (x <= 0.04045) return x / 12.92;
        return std.math.pow(f32, (x + 0.055) / 1.055, 2.4);
    }

    /// Convert a linear channel to sRGB.
    fn linearChannelToSrgb(x: f32) f32 {
        if (x <= 0.0031308) return 12.92 * x;
        return 1.055 * std.math.pow(f32, x, 1.0 / 2.4) - 0.055;
    }

    /// Assumes this color is in sRGB (nonlinear) and returns linear RGB. :contentReference[oaicite:4]{index=4}
    pub fn srgbToLinear(c: Color) Color {
        return .{
            .r = srgbChannelToLinear(c.r),
            .g = srgbChannelToLinear(c.g),
            .b = srgbChannelToLinear(c.b),
            .a = c.a,
        };
    }

    /// Assumes this color is linear and returns sRGB (nonlinear). :contentReference[oaicite:5]{index=5}
    pub fn linearToSrgb(c: Color) Color {
        return .{
            .r = linearChannelToSrgb(c.r),
            .g = linearChannelToSrgb(c.g),
            .b = linearChannelToSrgb(c.b),
            .a = c.a,
        };
    }

    // ─────────────────────────────────────────────
    // HTML Hex parsing / formatting
    // ─────────────────────────────────────────────

    pub const HtmlError = error{
        InvalidLength,
        InvalidHex,
    };

    /// Parse "#RRGGBB", "RRGGBB", "#RRGGBBAA", or "RRGGBBAA".
    pub fn fromHtml(code: []const u8) HtmlError!Color {
        const s = if (code.len > 0 and code[0] == '#') code[1..] else code;
        if (!(s.len == 6 or s.len == 8)) return HtmlError.InvalidLength;

        const r8 = try parseHexByte(s[0..2]);
        const g8 = try parseHexByte(s[2..4]);
        const b8 = try parseHexByte(s[4..6]);
        const a8: u8 = if (s.len == 8) try parseHexByte(s[6..8]) else 255;

        return rgba8(r8, g8, b8, a8);
    }

    /// Write hex into a caller-provided buffer. Returns slice length used.
    /// If with_alpha = true => "RRGGBBAA" else "RRGGBB".
    pub fn toHtml(c: Color, with_alpha: bool, out: []u8) ![]u8 {
        const needed: usize = if (with_alpha) 8 else 6;
        if (out.len < needed) return error.NoSpaceLeft;

        const r8 = toU8Clamp(c.r);
        const g8 = toU8Clamp(c.g);
        const b8 = toU8Clamp(c.b);
        const a8 = toU8Clamp(c.a);

        writeHexByte(out[0..2], r8);
        writeHexByte(out[2..4], g8);
        writeHexByte(out[4..6], b8);
        if (with_alpha) writeHexByte(out[6..8], a8);

        return out[0..needed];
    }

    // ─────────────────────────────────────────────
    // Common Color Constants
    // ─────────────────────────────────────────────
    pub const ALICE_BLUE = Color{ .r = 0.941176, .g = 0.972549, .b = 1.0, .a = 1.0 };
    pub const ANTIQUE_WHITE = Color{ .r = 0.980392, .g = 0.921569, .b = 0.843137, .a = 1.0 };
    pub const AQUA = Color{ .r = 0.0, .g = 1.0, .b = 1.0, .a = 1.0 };
    pub const AQUAMARINE = Color{ .r = 0.498039, .g = 1.0, .b = 0.831373, .a = 1.0 };
    pub const AZURE = Color{ .r = 0.941176, .g = 1.0, .b = 1.0, .a = 1.0 };

    pub const BEIGE = Color{ .r = 0.960784, .g = 0.960784, .b = 0.862745, .a = 1.0 };
    pub const BISQUE = Color{ .r = 1.0, .g = 0.894118, .b = 0.768627, .a = 1.0 };
    pub const BLACK = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    pub const BLANCHED_ALMOND = Color{ .r = 1.0, .g = 0.921569, .b = 0.803922, .a = 1.0 };
    pub const BLUE = Color{ .r = 0.0, .g = 0.0, .b = 1.0, .a = 1.0 };
    pub const BLUE_VIOLET = Color{ .r = 0.541176, .g = 0.168627, .b = 0.886275, .a = 1.0 };

    pub const BROWN = Color{ .r = 0.647059, .g = 0.164706, .b = 0.164706, .a = 1.0 };
    pub const BURLYWOOD = Color{ .r = 0.870588, .g = 0.721569, .b = 0.529412, .a = 1.0 };

    pub const CADET_BLUE = Color{ .r = 0.372549, .g = 0.619608, .b = 0.627451, .a = 1.0 };
    pub const CHARTREUSE = Color{ .r = 0.498039, .g = 1.0, .b = 0.0, .a = 1.0 };
    pub const CHOCOLATE = Color{ .r = 0.823529, .g = 0.411765, .b = 0.117647, .a = 1.0 };
    pub const CORAL = Color{ .r = 1.0, .g = 0.498039, .b = 0.313725, .a = 1.0 };
    pub const CORNFLOWER_BLUE = Color{ .r = 0.392157, .g = 0.584314, .b = 0.929412, .a = 1.0 };
    pub const CORNSILK = Color{ .r = 1.0, .g = 0.972549, .b = 0.862745, .a = 1.0 };
    pub const CRIMSON = Color{ .r = 0.862745, .g = 0.078431, .b = 0.235294, .a = 1.0 };

    pub const CYAN = Color{ .r = 0.0, .g = 1.0, .b = 1.0, .a = 1.0 };

    pub const DARK_BLUE = Color{ .r = 0.0, .g = 0.0, .b = 0.545098, .a = 1.0 };
    pub const DARK_CYAN = Color{ .r = 0.0, .g = 0.545098, .b = 0.545098, .a = 1.0 };
    pub const DARK_GRAY = Color{ .r = 0.662745, .g = 0.662745, .b = 0.662745, .a = 1.0 };
    pub const DARK_GREEN = Color{ .r = 0.0, .g = 0.392157, .b = 0.0, .a = 1.0 };
    pub const DARK_MAGENTA = Color{ .r = 0.545098, .g = 0.0, .b = 0.545098, .a = 1.0 };
    pub const DARK_RED = Color{ .r = 0.545098, .g = 0.0, .b = 0.0, .a = 1.0 };

    pub const FUCHSIA = Color{ .r = 1.0, .g = 0.0, .b = 1.0, .a = 1.0 };
    pub const GOLD = Color{ .r = 1.0, .g = 0.843137, .b = 0.0, .a = 1.0 };
    pub const GRAY = Color{ .r = 0.745098, .g = 0.745098, .b = 0.745098, .a = 1.0 };
    pub const GREEN = Color{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 };
    pub const HOT_PINK = Color{ .r = 1.0, .g = 0.411765, .b = 0.705882, .a = 1.0 };

    pub const LIME = Color{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 };
    pub const MAGENTA = Color{ .r = 1.0, .g = 0.0, .b = 1.0, .a = 1.0 };

    pub const NAVY_BLUE = Color{ .r = 0.0, .g = 0.0, .b = 0.501961, .a = 1.0 };
    pub const OLIVE = Color{ .r = 0.501961, .g = 0.501961, .b = 0.0, .a = 1.0 };
    pub const ORANGE = Color{ .r = 1.0, .g = 0.647059, .b = 0.0, .a = 1.0 };

    pub const PURPLE = Color{ .r = 0.501961, .g = 0.0, .b = 0.501961, .a = 1.0 };
    pub const RED = Color{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    pub const SILVER = Color{ .r = 0.752941, .g = 0.752941, .b = 0.752941, .a = 1.0 };
    pub const TEAL = Color{ .r = 0.0, .g = 0.501961, .b = 0.501961, .a = 1.0 };
    pub const TRANSPARENT = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 };
    pub const WHITE = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
    pub const YELLOW = Color{ .r = 1.0, .g = 1.0, .b = 0.0, .a = 1.0 };

    // Debug / editor-friendly colors
    pub const DEBUG_RED = Color{ .r = 1, .g = 0.2, .b = 0.2, .a = 1 };
    pub const DEBUG_GREEN = Color{ .r = 0.2, .g = 1, .b = 0.2, .a = 1 };
    pub const DEBUG_BLUE = Color{ .r = 0.2, .g = 0.6, .b = 1, .a = 1 };
    pub const DEBUG_YELLOW = Color{ .r = 1, .g = 1, .b = 0.3, .a = 1 };
};

fn toU8Clamp(x: f32) u8 {
    const clamped = std.math.clamp(x, 0.0, 1.0);
    return @intFromFloat(@round(clamped * 255.0));
}

fn hexNibble(c: u8) Color.HtmlError!u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => Color.HtmlError.InvalidHex,
    };
}

fn parseHexByte(two: []const u8) Color.HtmlError!u8 {
    if (two.len != 2) return Color.HtmlError.InvalidLength;
    const hi = try hexNibble(two[0]);
    const lo = try hexNibble(two[1]);
    return (hi << 4) | lo;
}

fn writeHexByte(dst2: []u8, v: u8) void {
    const hex = "0123456789abcdef";
    dst2[0] = hex[(v >> 4) & 0xF];
    dst2[1] = hex[v & 0xF];
}

test "Color.fromHtml / toHtml round trip" {
    var buf: [8]u8 = undefined;

    const c = try Color.fromHtml("#33cc99ff");
    const s = try Color.toHtml(c, true, buf[0..]);
    try std.testing.expectEqualStrings("33cc99ff", s);

    const c2 = try Color.fromHtml("33cc99");
    var buf2: [6]u8 = undefined;
    const s2 = try Color.toHtml(c2, false, buf2[0..]);
    try std.testing.expectEqualStrings("33cc99", s2);
}
