const std = @import("std");
const zigimg = @import("zigimg");

pub fn main() !void {
    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Read image
    const image = try zigimg.Image.fromFilePath(allocator, "test.png");
    defer image.deinit();
}
