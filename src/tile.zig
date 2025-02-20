const std = @import("std");
const Color = @import("color.zig").Color;

pub const Tile = struct {
    colors: []const Color,
    freq: u32,

    pub fn init(colors: []const Color, freq: u32) @This() {
        return .{ .colors = colors, .freq = freq };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        allocator.free(self.colors);
    }

    pub fn eql(a: []const Color, b: []const Color) bool {
        if (a.len != b.len) return false;
        for (a, b) |*color_a, *color_b| {
            if (!Color.eql(color_a, color_b)) return false;
        }
        return true;
    }
};
