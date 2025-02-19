const std = @import("std");
const termsize = @import("termsize");
const Color = @import("color.zig").Color;

pub const Term = struct {
    width: usize,
    height: usize,
    pixels: []Color,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        // Get terminal info
        const size: ?termsize.TermSize = try termsize.termSize(std.io.getStdOut());
        const actual_width: usize = size.?.width / 3;
        const pixels: []Color = try allocator.alloc(Color, actual_width * size.?.height);
        // Start all colors as black
        for (pixels) |*pixel| {
            pixel.* = .{ .r = 0, .g = 0, .b = 0 };
        }
        // Create the terminal struct
        return Term{
            .width = actual_width,
            .height = size.?.height,
            .pixels = pixels,
        };
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
    }

    pub fn setPixel(self: *@This(), x: usize, y: usize, pixel: Color) void {
        if (x < self.width and y < self.height) {
            self.pixels[y * self.width + x] = pixel;
        }
    }

    pub fn draw(self: @This()) void {
        std.debug.print("\x1B[2J\x1B[H", .{});
        for (self.pixels, 0..) |pixel, i| {
            const x = i % self.width;
            const y = i / self.width;
            if (x == 0 and y != 0) {
                std.debug.print("\n", .{});
            }
            std.debug.print("\x1B[48;2;{};{};{}m   ", .{ pixel.r, pixel.g, pixel.b });
        }
        std.debug.print("\x1B[0m\n", .{});
    }
};
