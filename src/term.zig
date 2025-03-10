const std = @import("std");
const Color = @import("color.zig").Color;
const builtin = @import("builtin");

const TermError = error{ Unexpected, Unsupported, IoctlError, DimensionError };

pub const TermSize = struct {
    width: u32,
    height: u32,

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
                var buf: std.posix.winsize = undefined;
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

// TODO: Add resize callback maybe?
pub const Term = struct {
    dimensions: TermSize,
    pixels: []Color,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        // Get terminal info
        const size: TermSize = try TermSize.getTerminalSize() orelse return error.DimensionError;
        const pixels: []Color = try allocator.alloc(Color, size.width * size.height);
        // Start all colors as black
        var term: Term = .{ .dimensions = size, .pixels = pixels };
        term.clearPixels();
        return term;
    }

    pub fn deinit(self: *const @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
    }

    pub fn setPixel(self: *@This(), x: u32, y: u32, pixel: Color) void {
        if (x < self.dimensions.width and y < self.dimensions.height) {
            self.pixels[y * self.dimensions.width + x] = pixel;
        }
    }

    pub fn clearPixels(self: *@This()) void {
        @memset(self.pixels, .{ .r = 0, .g = 0, .b = 0 });
    }

    pub fn draw(self: *const @This()) !void {
        // Base variables to print to console
        const stdout = std.io.getStdOut().writer();
        var buf_writer = std.io.bufferedWriter(stdout);
        var writer = buf_writer.writer();
        // Clear screen and move cursor to top-left
        try writer.writeAll("\x1B[H");
        // Draw pixels
        for (0..self.dimensions.height) |y| {
            if (y != 0) try writer.writeByte('\n');
            for (0..self.dimensions.width) |x| {
                const pixel = self.pixels[y * self.dimensions.width + x];
                try writer.print("\x1B[48;2;{};{};{}m   ", .{ pixel.r, pixel.g, pixel.b });
            }
            try writer.writeAll("\x1B[0m");
        }
        // Reset color and move cursor back to home position
        try writer.writeAll("\x1B[0m\x1B[H");
        try buf_writer.flush();
    }
};
