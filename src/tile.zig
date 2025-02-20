const std = @import("std");
const Color = @import("color.zig").Color;

pub const Direction = enum { up, down, left, right };

pub const Tile = struct {
    colors: []const Color,
    freq: u32,
    // TODO: Implement adjacencies
    adjacencies: [4]std.ArrayList(usize), // Indexed using Direction

    pub fn init(allocator: *const std.mem.Allocator, colors: []const Color, freq: u32) @This() {
        return .{
            .colors = colors,
            .freq = freq,
            .adjacencies = .{
                std.ArrayList(usize).init(allocator.*),
                std.ArrayList(usize).init(allocator.*),
                std.ArrayList(usize).init(allocator.*),
                std.ArrayList(usize).init(allocator.*),
            },
        };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        allocator.free(self.colors);
        for (&self.adjacencies) |*adj| {
            adj.deinit();
        }
    }

    pub fn eql(a: *const @This(), b: []const Color) bool {
        if (a.colors.len != b.len) return false;
        for (a.colors, b) |*color_a, *color_b| {
            if (!color_a.eql(color_b)) return false;
        }
        return true;
    }
};
