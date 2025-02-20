const std = @import("std");
const TileSet = @import("tileset.zig").TileSet;
const Term = @import("term.zig").Term;
const WfcMap = @import("wfcmap.zig").WfcMap;

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
    const tileset: TileSet = try TileSet.init(&allocator, "samples/Dungeon.png", tile_size);
    defer tileset.deinit(&allocator);
    // Create a map
    const wfc_map: WfcMap = try WfcMap.init(&allocator, &tileset, terminal.dimensions.width, terminal.dimensions.height);
    defer wfc_map.deinit(&allocator);
    // Debug stuff
    std.debug.print("Tilecount: {}", .{tileset.tiles.len});
    for (wfc_map.cells, 0..) |cell, i| {
        const x = i % terminal.dimensions.width;
        const y = i / terminal.dimensions.width;
        var sum_r: u32 = 0;
        var sum_g: u32 = 0;
        var sum_b: u32 = 0;
        for (cell) |idx| {
            sum_r += tileset.tiles[idx].colors[4].r;
            sum_g += tileset.tiles[idx].colors[4].g;
            sum_b += tileset.tiles[idx].colors[4].b;
        }
        terminal.setPixel(x, y, .{ .r = @intCast(sum_r / cell.len), .g = @intCast(sum_g / cell.len), .b = @intCast(sum_b / cell.len) });
    }
    try terminal.draw();
}
