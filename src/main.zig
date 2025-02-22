const std = @import("std");
const TileSet = @import("tileset.zig").TileSet;
const Term = @import("term.zig").Term;
const WfcMap = @import("wfcmap.zig").WfcMap;

const FileError = error{FileNotFound};

pub fn main() !void {
    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Read command arguments
    const argv: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    // Get the file name
    if (argv.len < 2) {
        // No file name
        return error.FileNotFound;
    }
    const filename: [:0]const u8 = argv[1];
    // Initialize a terminal object
    var terminal: Term = try Term.init(&allocator);
    defer terminal.deinit(&allocator);
    // Get the tiles
    const tile_size_val: u8 = 2;
    const tile_size: u8 = tile_size_val * 2 - 1;
    var tileset: TileSet = try TileSet.init(&allocator, filename, tile_size);
    defer tileset.deinit(&allocator);
    // Create a map
    var wfc_map: WfcMap = try WfcMap.init(&allocator, &tileset, terminal.dimensions.width, terminal.dimensions.height);
    defer wfc_map.deinit(&allocator);
    // Print wfc state
    while (!try wfc_map.step(&allocator)) {
        const tile_center_idx: usize = tile_size * tile_size / 2;
        for (wfc_map.cells, 0..) |*cell, i| {
            const x: u32 = @as(u32, @intCast(i)) % terminal.dimensions.width;
            const y: u32 = @as(u32, @intCast(i)) / terminal.dimensions.width;
            // Calculate average color
            var total_entropy: u32 = 0;
            var sum_r: u32 = 0;
            var sum_g: u32 = 0;
            var sum_b: u32 = 0;
            var cell_it = cell.possible.iterator(.{});
            while (cell_it.next()) |tile| {
                total_entropy += tileset.tiles[tile].freq;
                sum_r += tileset.tiles[tile].colors[tile_center_idx].r * tileset.tiles[tile].freq;
                sum_g += tileset.tiles[tile].colors[tile_center_idx].g * tileset.tiles[tile].freq;
                sum_b += tileset.tiles[tile].colors[tile_center_idx].b * tileset.tiles[tile].freq;
            }
            terminal.setPixel(x, y, .{ .r = @intCast(sum_r / total_entropy), .g = @intCast(sum_g / total_entropy), .b = @intCast(sum_b / total_entropy) });
        }
        try terminal.draw();
    }
}
