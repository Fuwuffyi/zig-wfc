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
    const tileset: TileSet = try TileSet.init(&allocator, "samples/Sewers.png", tile_size);
    defer tileset.deinit(&allocator);
    // Create a map
    const wfc_map: WfcMap = try WfcMap.init(&allocator, &tileset, terminal.dimensions.width, terminal.dimensions.height);
    defer wfc_map.deinit(&allocator);
    // Print current wfc state
    // const tile_center_idx: usize = tile_size * tile_size / 2;
    // for (wfc_map.cells, 0..) |*cell, i| {
    //     const x: u32 = @as(u32, @intCast(i)) % terminal.dimensions.width;
    //     const y: u32 = @as(u32, @intCast(i)) / terminal.dimensions.width;
    //     var total_entropy: u32 = 0;
    //     var sum_r: u32 = 0;
    //     var sum_g: u32 = 0;
    //     var sum_b: u32 = 0;
    //     for (cell.items) |idx| {
    //         total_entropy += tileset.tiles[idx].freq;
    //         sum_r += tileset.tiles[idx].colors[tile_center_idx].r * tileset.tiles[idx].freq;
    //         sum_g += tileset.tiles[idx].colors[tile_center_idx].g * tileset.tiles[idx].freq;
    //         sum_b += tileset.tiles[idx].colors[tile_center_idx].b * tileset.tiles[idx].freq;
    //     }
    //     terminal.setPixel(x, y, .{ .r = @intCast(sum_r / total_entropy), .g = @intCast(sum_g / total_entropy), .b = @intCast(sum_b / total_entropy) });
    // }
    // try terminal.draw();

    // Debug stuff
    // Print the count of adjacencies of the first tile
    test_adjacencies(0, 23, &tileset, tile_size, &terminal);
    test_adjacencies(1, 5, &tileset, tile_size, &terminal);
    test_adjacencies(2, 69, &tileset, tile_size, &terminal);
    test_adjacencies(3, 54, &tileset, tile_size, &terminal);
    test_adjacencies(4, 33, &tileset, tile_size, &terminal);
    test_adjacencies(5, 1, &tileset, tile_size, &terminal);
    try terminal.draw();
}

pub fn test_adjacencies(hy: u32, idx: u32, tileset: *const TileSet, tile_size: u32, terminal: *Term) void {
    const first_tile = &tileset.tiles[idx];
    for (0..tile_size) |dy| {
        for (0..tile_size) |dx| {
            const pixel = first_tile.colors[dy * tile_size + dx];
            terminal.setPixel(@as(u32, @intCast(dx)), (hy * 4) + @as(u32, @intCast(dy)), pixel);
        }
    }
    const left_adjacencies = first_tile.adjacencies[3].items;
    for (left_adjacencies, 1..) |adj, i| {
        // Draw them to the terminal
        const x: u32 = (@as(u32, @intCast(i)) * (tile_size + 1)) % terminal.dimensions.width;
        const y: u32 = (@as(u32, @intCast(i)) * (tile_size + 1)) / terminal.dimensions.width;
        const adj_tile = &tileset.tiles[adj];
        for (0..tile_size) |dy| {
            for (0..tile_size) |dx| {
                const pixel = adj_tile.colors[dy * tile_size + dx];
                terminal.setPixel(x + @as(u32, @intCast(dx)), (hy * 4) + y + @as(u32, @intCast(dy)), pixel);
            }
        }
    }
}
