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
        var buffer: [16384]u8 = undefined;
        var current_offset: usize = 0;
        const first_write: []u8 = try std.fmt.bufPrint(&buffer, "\x1B[2J\x1B[H", .{});
        current_offset = first_write.len;
        for (self.pixels, 0..) |pixel, i| {
            const x = i % self.width;
            const y = i / self.width;
            if (x == 0 and y != 0) {
                const other_write: []u8 = try std.fmt.bufPrint(buffer[current_offset..], "\n", .{});
                current_offset += other_write.len;
            }
            const other_write: []u8 = try std.fmt.bufPrint(buffer[current_offset..], "\x1B[48;2;{};{};{}m   ", .{ pixel.r, pixel.g, pixel.b });
            current_offset += other_write.len;
            if (current_offset > buffer.len - 200) {
                std.debug.print("{s}", .{buffer[0..current_offset]});
                current_offset = 0;
            }
        }
        const last_write: []u8 = try std.fmt.bufPrint(buffer[current_offset..], "\x1B[0m\n", .{});
        current_offset += last_write.len;
        std.debug.print("{s}", .{buffer[0..current_offset]});
    }
};
