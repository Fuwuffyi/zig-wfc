const std = @import("std");
const Color = @import("color.zig").Color;
const builtin = @import("builtin");

const TermError = error{ Unexpected, Unsupported, IoctlError, DimensionError };

// TODO: Add resize callback maybe?
pub const TermSize = struct {
    width: usize,
    height: usize,

    // Edit of https://github.com/softprops/zig-termsize.git
    pub fn getTerminalSize() !?TermSize {
        const term: std.fs.File = std.io.getStdOut();
        return switch (builtin.os.tag) {
            .windows => blk: {
                var buf: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
                break :blk switch (std.os.windows.kernel32.GetConsoleScreenBufferInfo(
                    term.handle,
                    &buf,
                )) {
                    std.os.windows.TRUE => TermSize{
                        .width = @intCast(@divFloor(@abs(buf.srWindow.Right - buf.srWindow.Left + 1), 3)),
                        .height = @intCast(buf.srWindow.Bottom - buf.srWindow.Top + 1),
                    },
                    else => error.Unexpected,
                };
            },
            .linux, .macos => blk: {
                var buf: std.posix.system.winsize = undefined;
                break :blk switch (std.posix.errno(
                    std.posix.system.ioctl(
                        term.handle,
                        std.posix.T.IOCGWINSZ,
                        @intFromPtr(&buf),
                    ),
                )) {
                    .SUCCESS => TermSize{
                        .width = buf.col / 3,
                        .height = buf.row,
                    },
                    else => error.IoctlError,
                };
            },
            else => error.Unsupported,
        };
    }
};

pub const Term = struct {
    dimensions: TermSize,
    pixels: []Color,
    buffer: []u8,

    pub fn init(allocator: *const std.mem.Allocator) !@This() {
        // Get terminal info
        const size: TermSize = try TermSize.getTerminalSize() orelse return error.DimensionError;
        const pixels: []Color = try allocator.alloc(Color, size.width * size.height);
        // Start all colors as black
        for (pixels) |*pixel| {
            pixel.* = .{ .r = 0, .g = 0, .b = 0 };
        }
        // Calculate buffer size
        const buffer_size: usize = (size.width * size.height * 22) + size.height + 11;
        const buffer: []u8 = try allocator.alloc(u8, buffer_size);
        // Create the terminal struct
        return Term{
            .dimensions = size,
            .pixels = pixels,
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *@This(), allocator: *const std.mem.Allocator) void {
        allocator.free(self.pixels);
        allocator.free(self.buffer);
    }

    pub fn setPixel(self: *@This(), x: usize, y: usize, pixel: Color) void {
        if (x < self.dimensions.width and y < self.dimensions.height) {
            self.pixels[y * self.dimensions.width + x] = pixel;
        }
    }

    pub fn clearPixels(self: *@This()) void {
        for (self.pixels) |*pixel| {
            pixel.* = .{ .r = 0, .g = 0, .b = 0 };
        }
    }

    pub fn draw(self: *const @This()) !void {
        // Base variables to print to console
        const stdout = std.io.getStdOut().writer();
        var current_offset: usize = 0;
        // Clear screen and move cursor to top-left
        const clear_screen: *const [7:0]u8 = "\x1B[2J\x1B[H";
        std.mem.copyForwards(u8, self.buffer[current_offset..], clear_screen);
        current_offset += clear_screen.len;
        // Draw pixels
        for (self.pixels, 0..) |*pixel, i| {
            const x = i % self.dimensions.width;
            const y = i / self.dimensions.width;
            // Add newline at the start of each row (except the first)
            if (x == 0 and y != 0) {
                self.buffer[current_offset] = '\n';
                current_offset += 1;
            }
            // Format pixel color and spaces
            const pixel_str: []u8 = try std.fmt.bufPrint(self.buffer[current_offset..], "\x1B[48;2;{};{};{}m   ", .{ pixel.r, pixel.g, pixel.b });
            current_offset += pixel_str.len;
        }
        // Reset color and add final newline
        const reset_color: *const [4:0]u8 = "\x1B[0m";
        std.mem.copyForwards(u8, self.buffer[current_offset..], reset_color);
        current_offset += reset_color.len;
        // Flush buffer
        try stdout.writeAll(self.buffer[0..current_offset]);
    }
};
