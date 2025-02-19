const std = @import("std");
const Tile = @import("tile.zig").Tile;

pub fn main() !void {
    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Get the tiles
    const tile_size: u8 = 3;
    const tiles = try Tile.generate_tiles(&allocator, "tilesets/Lake.png", tile_size);
    defer allocator.free(tiles);
    // Read the tile data
    for (tiles) |tile| {
        defer tile.deinit(&allocator);
        std.debug.print("Hash: {}", .{tile.color_hash()});
    }
}
