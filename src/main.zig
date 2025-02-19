const std = @import("std");
const Tile = @import("tile.zig").Tile;
const Term = @import("term.zig").Term;

pub fn main() !void {
    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Initialize a terminal object
    var terminal: Term = try Term.init(allocator);
    defer terminal.deinit(allocator);
    // Get the tiles
    const tile_size: u8 = 3;
    const tiles = try Tile.generate_tiles(&allocator, "tilesets/Lake.png", tile_size);
    defer allocator.free(tiles);
    // Debug stuff
    std.debug.print("Tilecount: {}", .{tiles.len});
    for (tiles) |tile| {
        defer tile.deinit(&allocator);
    }
    // Debug terminal

    for (1..500) |i| {
        const x: usize = (i / 10) % 10;
        const y: usize = (i % 10) % 10;
        const ox: usize = ((i - 1) / 10) % 10;
        const oy: usize = ((i - 1) % 10) % 10;
        terminal.setPixel(x, y, .{ .r = 255, .g = 0, .b = 0 });
        terminal.setPixel(ox, oy, .{ .r = 0, .g = 255, .b = 0 });
        try terminal.draw();
    }
}
