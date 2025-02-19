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
    for (tiles, 0..) |tile, i| {
        defer tile.deinit(&allocator);
        // Calculate terminal coordinates
        const x = (i % terminal.dimensions.width) * tile_size;
        const y = (i / terminal.dimensions.width) * tile_size;
        // Draw the tile
        for (tile.colors, 0..) |color, j| {
            const x_offset = j % tile_size;
            const y_offset = j / tile_size;
            terminal.setPixel(x + x_offset, y + y_offset, color);
        }
    }
    try terminal.draw();
}
