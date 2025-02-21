const std = @import("std");
const Tile = @import("tile.zig").Tile;
const TileSet = @import("tileset.zig").TileSet;

// TODO: Hardcoded seed...
var random_generator: std.Random.Xoshiro256 = std.Random.DefaultPrng.init(0);
const random: std.Random = random_generator.random();

pub const WfcMap = struct {
    cells: []std.ArrayList(u32),
    tileset: *const TileSet,

    pub fn init(allocator: *const std.mem.Allocator, tileset: *const TileSet, width: usize, height: usize) !@This() {
        const cells: []std.ArrayList(u32) = try allocator.alloc(std.ArrayList(u32), width * height);
        for (cells) |*cell| {
            cell.* = std.ArrayList(u32).init(allocator.*);
            for (0..tileset.tiles.len) |i| {
                try cell.append(@intCast(i));
            }
        }
        return .{ .cells = cells, .tileset = tileset };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        for (self.cells) |*cell| {
            cell.deinit();
        }
        allocator.free(self.cells);
    }

    pub fn step(self: *@This(), allocator: *const std.mem.Allocator) !bool {
        // Get lowest entropy elements
        var lowest_entropy: u32 = std.math.maxInt(u32);
        var lowest_entropy_cells: std.ArrayList(usize) = std.ArrayList(usize).init(allocator.*);
        defer lowest_entropy_cells.deinit();
        for (self.cells, 0..) |*cell, m_idx| {
            // Skip already collapsed elements
            if (cell.items.len <= 1) continue;
            // Calculate entropy
            var cell_entropy: u32 = 0;
            for (cell.items) |c_idx| {
                cell_entropy += self.tileset.tiles[c_idx].freq;
            }
            // Clear list if new entropy record found
            if (cell_entropy < lowest_entropy) {
                lowest_entropy_cells.clearAndFree();
                lowest_entropy = cell_entropy;
            }
            // Add entropy cell if it has same entropy as best
            if (cell_entropy == lowest_entropy) {
                try lowest_entropy_cells.append(m_idx);
            }
        }
        // If the lowest entropy does not change, we have collapsed all cells
        if (lowest_entropy == std.math.maxInt(u32)) return true;
        // Collapse a random lowest entropy element
        const rand_index: usize = lowest_entropy_cells.items[random.int(usize) % lowest_entropy_cells.items.len];
        var rand_cell: *std.ArrayList(u32) = &self.cells[rand_index];
        const random_tile: u32 = rand_cell.items[random.int(usize) % rand_cell.items.len];
        rand_cell.clearAndFree();
        try rand_cell.append(random_tile);
        // Not finished collapsing everything yet
        return false;
    }
};
