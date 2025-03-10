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
    var terminal: Term = try Term.init(allocator);
    defer terminal.deinit(allocator);
    // Get the tiles
    const tile_size_val: u8 = 2;
    const tile_size: u8 = tile_size_val * 2 - 1;
    var tileset: TileSet = try TileSet.init(allocator, filename, tile_size);
    defer tileset.deinit(allocator);
    // Create a map
    var wfc_map: WfcMap = try WfcMap.init(allocator, &tileset, terminal.dimensions.width, terminal.dimensions.height);
    defer wfc_map.deinit(allocator);
    // Print wfc state
    var finished_wfc: bool = false;
    while (!finished_wfc) {
        finished_wfc = wfc_map.step(allocator) catch |err| blk: {
            if (err == error.Contradiction) {
                wfc_map.reset();
                break :blk false;
            }
            unreachable;
        };
        for (wfc_map.cells, 0..) |*row, i| {
            for (0..row.len) |j| {
                const x: u32 = @intCast(j);
                const y: u32 = @intCast(i);
                terminal.setPixel(x, y, wfc_map.get_color_at(x, y));
            }
        }
        try terminal.draw();
    }
}
