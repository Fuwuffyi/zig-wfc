const std = @import("std");
const Tile = @import("tile.zig").Tile;
const Term = @import("term.zig").Term;

pub fn main() !void {
    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Initialize a terminal object
    var terminal: Term = try Term.init(&allocator);
    defer terminal.deinit(&allocator);
    // Get the tiles
    const tile_size_val: u8 = 2;
    const tile_size: u8 = tile_size_val * 2 - 1;
    const tiles = try Tile.generate_tiles(&allocator, "test.png", tile_size);
    defer allocator.free(tiles);
    // Debug stuff
    std.debug.print("Tilecount: {}", .{tiles.len});
    for (tiles, 0..) |tile, i| {
        defer tile.deinit(&allocator);
        // Draw all the tiles to the terminal
        const x = (i % 16) * (tile_size + 1);
        const y = (i / 16) * (tile_size + 1);
        for (tile.colors, 0..) |color, j| {
            const x_offset = j % tile_size;
            const y_offset = j / tile_size;
            terminal.setPixel(x + x_offset, y + y_offset, color);
        }
    }
    try terminal.draw();
}
