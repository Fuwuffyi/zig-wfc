const std = @import("std");
const Tile = @import("tile.zig").Tile;

pub fn main() !void {
    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Get the tiles
    const tile_size: u8 = 3;
    const tiles = try Tile.generate_tiles(&allocator, "test.png", tile_size);
    defer allocator.free(tiles);
    // Read the tile data
    for (tiles, 0..) |tile, i| {
        defer tile.deinit(&allocator);
        std.debug.print("\nTile: {}\n", .{i});
        for (tile.colors, 0..) |col, ci| {
            if (ci % tile_size == 0) std.debug.print("\n", .{});
            std.debug.print("\x1b[38;2;{};{};{}m\x1b[48;2;{};{};{}m   \x1b[0m", .{ col.r, col.g, col.b, col.r, col.g, col.b });
        }
    }
}
