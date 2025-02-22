const std = @import("std");
const Tile = @import("tile.zig").Tile;
const Direction = @import("tile.zig").Direction;
const TileSet = @import("tileset.zig").TileSet;

const WfcError = error{Contradiction};

// TODO: Hardcoded seed...
var random_generator: std.Random.Xoshiro256 = std.Random.DefaultPrng.init(0);
const random: std.Random = random_generator.random();

pub const WfcMap = struct {
    cells: []std.DynamicBitSet,
    width: u32,
    height: u32,
    tileset: *const TileSet,

    pub fn init(allocator: *const std.mem.Allocator, tileset: *const TileSet, width: u32, height: u32) !@This() {
        const num_tiles: usize = tileset.tiles.len;
        const cells: []std.DynamicBitSet = try allocator.alloc(std.DynamicBitSet, width * height);
        for (cells) |*cell| {
            cell.* = try std.DynamicBitSet.initEmpty(allocator.*, num_tiles);
            cell.*.setRangeValue(.{ .start = 0, .end = num_tiles }, true);
        }
        return .{ .cells = cells, .width = width, .height = height, .tileset = tileset };
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
            if (cell.count() <= 1) continue;
            // Calculate entropy
            var cell_entropy: u32 = 0;
            var possible_it = cell.iterator(.{});
            while (possible_it.next()) |tile| {
                cell_entropy += self.tileset.tiles[tile].freq;
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
        var rand_cell = &self.cells[rand_index];
        const random_tile: u32 = selectTileByFrequency(self.tileset, rand_cell);
        rand_cell.deinit();
        rand_cell.* = try std.DynamicBitSet.initEmpty(allocator.*, self.tileset.tiles.len);
        rand_cell.set(random_tile);
        // Propagate collapse to adjacent tiles
        try self.update_neighbors(allocator, rand_index);
        // Not finished collapsing everything yet
        return false;
    }

    fn selectTileByFrequency(tileset: *const TileSet, possible: *const std.DynamicBitSet) u32 {
        var total: u32 = 0;
        var it = possible.iterator(.{});
        while (it.next()) |tile| {
            total += tileset.tiles[tile].freq;
        }
        var rand = random.int(u32) % total;
        it = possible.iterator(.{});
        while (it.next()) |tile| {
            const freq = tileset.tiles[tile].freq;
            if (rand < freq) return @intCast(tile);
            rand -= freq;
        }
        unreachable;
    }

    fn update_neighbors(self: *@This(), allocator: *const std.mem.Allocator, starting_index: usize) !void {
        // Create queue of cells to update
        var cell_queue: std.ArrayList(usize) = std.ArrayList(usize).init(allocator.*);
        defer cell_queue.deinit();
        try cell_queue.append(starting_index);
        // Update cells for as long as they are in the queue
        while (cell_queue.popOrNull()) |current_index| {
            // Get current cell data
            const current_cell = &self.cells[current_index];
            const current_x: u32 = @as(u32, @intCast(current_index % self.width));
            const current_y: u32 = @as(u32, @intCast(current_index / self.width));
            // Loop over the directions
            for (std.enums.values(Direction)) |dir| {
                // Get neighbor cell's position
                var nx: u32 = current_x;
                var ny: u32 = current_y;
                switch (dir) {
                    .up => {
                        if (current_y == 0) continue;
                        ny -= 1;
                    },
                    .down => {
                        if (current_y >= self.height - 1) continue;
                        ny += 1;
                    },
                    .left => {
                        if (current_x == 0) continue;
                        nx -= 1;
                    },
                    .right => {
                        if (current_x >= self.width - 1) continue;
                        nx += 1;
                    },
                }
                // Calculate the neighbor's index
                const neighbor_index: usize = @as(usize, @intCast(ny * self.width + nx));
                const neighbor_cell = &self.cells[neighbor_index];
                // Skip the neighbor if already collapsed
                if (neighbor_cell.count() <= 1) continue;
                // Get map of allowed indices based on the direction
                var allowed = try std.DynamicBitSet.initEmpty(allocator.*, self.tileset.tiles.len);
                defer allowed.deinit();
                var it = current_cell.iterator(.{});
                while (it.next()) |tile| {
                    const adj = &self.tileset.tiles[tile].adjacencies[@intFromEnum(dir)];
                    allowed.setUnion(adj.*);
                }
                const prev_count = neighbor_cell.count();
                neighbor_cell.setIntersection(allowed);
                const new_count = neighbor_cell.count();
                if (new_count == 0) return error.Contradiction;
                if (new_count < prev_count) {
                    try cell_queue.append(neighbor_index);
                }
            }
        }
    }
};
