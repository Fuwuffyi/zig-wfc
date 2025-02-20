const std = @import("std");
const Tile = @import("tile.zig").Tile;
const TileSet = @import("tileset.zig").TileSet;

pub const WfcMap = struct {
    cells: []std.ArrayList(usize),

    pub fn init(allocator: *const std.mem.Allocator, tileset: *const TileSet, width: usize, height: usize) !@This() {
        const cells: []std.ArrayList(usize) = try allocator.alloc(std.ArrayList(usize), width * height);
        for (cells) |*cell| {
            cell.* = std.ArrayList(usize).init(allocator.*);
            for (0..tileset.tiles.len) |i| {
                try cell.append(i);
            }
        }
        return .{ .cells = cells };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        for (self.cells) |*cell| {
            cell.deinit();
        }
        allocator.free(self.cells);
    }

    // TODO: Implement the collapse method
};
