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

    pub fn draw(self: @This()) !void {
        // Base variables to print to console
        const stdout = std.io.getStdOut().writer();
        var buffer: [32768]u8 = undefined;
        var current_offset: usize = 0;
        // Clear screen and move cursor to top-left
        const clear_screen = "\x1B[2J\x1B[H";
        std.mem.copyForwards(u8, buffer[current_offset..], clear_screen);
        current_offset += clear_screen.len;
        // Draw pixels
        for (self.pixels, 0..) |pixel, i| {
            const x = i % self.width;
            const y = i / self.width;
            // Add newline at the start of each row (except the first)
            if (x == 0 and y != 0) {
                buffer[current_offset] = '\n';
                current_offset += 1;
            }
            // Format pixel color and spaces
            const pixel_str = try std.fmt.bufPrint(buffer[current_offset..], "\x1B[48;2;{};{};{}m   ", .{ pixel.r, pixel.g, pixel.b });
            current_offset += pixel_str.len;
            // Flush buffer if it's nearly full
            if (current_offset > buffer.len - 100) {
                try stdout.writeAll(buffer[0..current_offset]);
                current_offset = 0;
            }
        }
        // Reset color and add final newline
        const reset_color = "\x1B[0m\n";
        std.mem.copyForwards(u8, buffer[current_offset..], reset_color);
        current_offset += reset_color.len;
        // Flush remaining buffer
        try stdout.writeAll(buffer[0..current_offset]);
    }
};
