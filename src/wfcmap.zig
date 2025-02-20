const std = @import("std");
const Tile = @import("tile.zig").Tile;
const TileSet = @import("tileset.zig").TileSet;

pub const WfcMap = struct {
    cells: [][]usize,

    pub fn init(allocator: *const std.mem.Allocator, tileset: *const TileSet, width: usize, height: usize) !@This() {
        const cells: [][]usize = try allocator.alloc([]usize, width * height);
        for (cells) |*cell| {
            cell.* = try allocator.alloc(usize, tileset.tiles.len);
            for (0..tileset.tiles.len) |i| {
                cell.*[i] = i;
            }
        }
        return .{ .cells = cells };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        for (self.cells) |*cell| {
            allocator.free(cell.*);
        }
        allocator.free(self.cells);
    }
};
