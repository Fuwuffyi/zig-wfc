const std = @import("std");
const TileSet = @import("tileset.zig").TileSet;
const Term = @import("term.zig").Term;
const WfcMap = @import("wfcmap.zig").WfcMap;
const WfcError = @import("wfcmap.zig").WfcError;

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
    var finished_wfc: bool = false;
    while (!finished_wfc) {
        finished_wfc = wfc_map.step(&allocator) catch |err| blk: {
            if (err == error.Contradiction) {
                wfc_map.reset();
                break :blk false;
            }
            unreachable;
        };
        for (wfc_map.cells, 0..) |*row, i| {
            for (row.*, 0..) |*cell, j| {
                const x: u32 = @intCast(j);
                const y: u32 = @intCast(i);
                var total_entropy: u32 = 0;
                var sum_r: u32 = 0;
                var sum_g: u32 = 0;
                var sum_b: u32 = 0;
                var cell_it = cell.possible.iterator(.{});
                while (cell_it.next()) |tile| {
                    total_entropy += tileset.tiles[tile].freq;
                    const clr = tileset.tiles[tile].get_color_at(tile_size / 2, tile_size / 2);
                    sum_r += clr.r * tileset.tiles[tile].freq;
                    sum_g += clr.g * tileset.tiles[tile].freq;
                    sum_b += clr.b * tileset.tiles[tile].freq;
                }
                terminal.setPixel(x, y, .{ .r = @intCast(sum_r / total_entropy), .g = @intCast(sum_g / total_entropy), .b = @intCast(sum_b / total_entropy) });
            }
        }
        try terminal.draw();
    }
}
